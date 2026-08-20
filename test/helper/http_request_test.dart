import 'dart:convert';

import 'package:fabric_flutter/helper/http_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Builds an [http.Response] with a JSON content type so [HTTPRequest.response]
/// takes the JSON decoding branch.
http.Response jsonResponse(
  String body,
  int statusCode, {
  String? reasonPhrase,
}) => http.Response(
  body,
  statusCode,
  headers: {'content-type': 'application/json; charset=utf-8'},
  reasonPhrase: reasonPhrase,
);

void main() {
  group('HTTPRequest', () {
    group('formattedCredentials', () {
      test('should combine the scheme name and the credentials', () {
        // Arrange
        const request = HTTPRequest(
          credentials: 'abc123',
          authScheme: AuthScheme.Bearer,
        );

        // Act
        final result = request.formattedCredentials;

        // Assert
        expect(result, 'Bearer abc123');
      });

      test('should support the Basic scheme', () {
        // Arrange
        const request = HTTPRequest(
          credentials: 'dXNlcjpwYXNz',
          authScheme: AuthScheme.Basic,
        );

        // Act
        final result = request.formattedCredentials;

        // Assert
        expect(result, 'Basic dXNlcjpwYXNz');
      });

      test('should return null when no credentials were configured', () {
        // Arrange
        const request = HTTPRequest();

        // Act
        final result = request.formattedCredentials;

        // Assert
        expect(result, isNull);
      });
    });

    group('headers', () {
      test('should expose the Authorization header when authenticated', () {
        // Arrange
        const request = HTTPRequest(
          credentials: 'token',
          authScheme: AuthScheme.JWT,
        );

        // Act
        final headers = request.headers;

        // Assert
        expect(headers, {'Authorization': 'JWT token'});
      });

      test('should return an empty map when no authentication is set', () {
        // Arrange
        const request = HTTPRequest();

        // Act
        final headers = request.headers;

        // Assert
        expect(headers, isEmpty);
      });
    });

    group('authenticated', () {
      test('should throw an error key for a 401 response', () {
        // Arrange
        final response = http.Response('', 401);

        // Act & Assert
        expect(
          () => HTTPRequest.authenticated(response),
          throwsA('error--401'),
        );
      });

      test('should throw an error key for a 403 response', () {
        // Arrange
        final response = http.Response('', 403);

        // Act & Assert
        expect(
          () => HTTPRequest.authenticated(response),
          throwsA('error--403'),
        );
      });

      test('should not throw for a successful response', () {
        // Arrange
        final response = http.Response('', 200);

        // Act & Assert
        expect(() => HTTPRequest.authenticated(response), returnsNormally);
      });
    });

    group('error', () {
      test('should return normally for any 2xx status code', () {
        // Arrange
        final ok = http.Response('', 200);
        final noContent = http.Response('', 204);
        final imUsed = http.Response('', 226);

        // Act & Assert
        expect(() => HTTPRequest.error(ok), returnsNormally);
        expect(() => HTTPRequest.error(noContent), returnsNormally);
        expect(() => HTTPRequest.error(imUsed), returnsNormally);
      });

      test('should prefer the JSON message field', () {
        // Arrange
        final response = jsonResponse(
          jsonEncode({'message': 'Invalid token'}),
          400,
          reasonPhrase: 'Bad Request',
        );

        // Act & Assert
        expect(() => HTTPRequest.error(response), throwsA('Invalid token'));
      });

      test('should join the errors list descriptions when no message', () {
        // Arrange
        final response = jsonResponse(
          jsonEncode({
            'errors': [
              {'description': 'first'},
              {'description': 'second'},
            ],
          }),
          422,
        );

        // Act & Assert
        expect(() => HTTPRequest.error(response), throwsA('first, second'));
      });

      test('should fall back to the reason phrase for a non-JSON body', () {
        // Arrange
        final response = http.Response(
          'not json',
          500,
          reasonPhrase: 'Internal Server Error',
        );

        // Act & Assert
        expect(
          () => HTTPRequest.error(response),
          throwsA('Internal Server Error'),
        );
      });

      test('should fall back to the status code key with no reason phrase', () {
        // Arrange
        final response = http.Response('not json', 503);

        // Act & Assert
        expect(() => HTTPRequest.error(response), throwsA('error--503'));
      });

      test('should ignore an empty reason phrase', () {
        // Arrange
        final response = http.Response('not json', 418, reasonPhrase: '');

        // Act & Assert
        expect(() => HTTPRequest.error(response), throwsA('error--418'));
      });
    });

    group('jsonDecodeAndClean', () {
      test('should remove null and empty string entries from a map', () {
        // Arrange
        final body = jsonEncode({
          'a': 1,
          'b': null,
          'c': '',
          'd': 'kept',
          'e': false,
        });

        // Act
        final result = HTTPRequest.jsonDecodeAndClean(body);

        // Assert
        expect(result, {'a': 1, 'd': 'kept', 'e': false});
      });

      test('should remove null and empty string items from a list', () {
        // Arrange
        final body = jsonEncode([1, null, '', 'kept']);

        // Act
        final result = HTTPRequest.jsonDecodeAndClean(body);

        // Assert
        expect(result, [1, 'kept']);
      });

      test('should return scalar JSON values unchanged', () {
        // Arrange
        const body = '42';

        // Act
        final result = HTTPRequest.jsonDecodeAndClean(body);

        // Assert
        expect(result, 42);
      });

      test('should keep nested empty values untouched', () {
        // Arrange
        final body = jsonEncode({
          'nested': {'inner': null},
        });

        // Act
        final result = HTTPRequest.jsonDecodeAndClean(body);

        // Assert
        expect(result, {
          'nested': {'inner': null},
        });
      });

      test('should throw on malformed JSON', () {
        // Arrange
        const body = '{not json';

        // Act & Assert
        expect(
          () => HTTPRequest.jsonDecodeAndClean(body),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('response', () {
      test('should decode and clean a JSON body', () {
        // Arrange
        final response = jsonResponse(
          jsonEncode({'id': '1', 'name': '', 'value': null, 'ok': true}),
          200,
        );

        // Act
        final result = HTTPRequest.response(response);

        // Assert
        expect(result, {'id': '1', 'ok': true});
      });

      test('should decode an application/x-json-stream body', () {
        // Arrange
        final response = http.Response(
          jsonEncode({'id': '1'}),
          200,
          headers: {'content-type': 'application/x-json-stream'},
        );

        // Act
        final result = HTTPRequest.response(response);

        // Assert
        expect(result, {'id': '1'});
      });

      test('should return null for an empty body', () {
        // Arrange
        final response = jsonResponse('', 200);

        // Act
        final result = HTTPRequest.response(response);

        // Assert
        expect(result, isNull);
      });

      test('should return raw text when the content type is not JSON', () {
        // Arrange
        final response = http.Response(
          'plain text',
          200,
          headers: {'content-type': 'text/plain'},
        );

        // Act
        final result = HTTPRequest.response(response);

        // Assert
        expect(result, 'plain text');
      });

      test('should return raw text when no content type header exists', () {
        // Arrange
        final response = http.Response('plain text', 200);

        // Act
        final result = HTTPRequest.response(response);

        // Assert
        expect(result, 'plain text');
      });

      test('should throw the error message before parsing the body', () {
        // Arrange
        final response = jsonResponse(jsonEncode({'message': 'nope'}), 400);

        // Act & Assert
        expect(() => HTTPRequest.response(response), throwsA('nope'));
      });
    });
  });
}
