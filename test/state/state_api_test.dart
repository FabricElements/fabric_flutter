import 'dart:convert';

import 'package:fabric_flutter/helper/http_request.dart';
import 'package:fabric_flutter/state/state_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/debounce.dart';

/// Concrete [StateAPI] used to exercise the abstract base class.
///
/// The state records every request it sends so tests can assert on the final
/// URL, method, headers, and body without touching the network.
class _TestStateAPI extends StateAPI {
  /// Creates a test state backed by [handler].
  _TestStateAPI(
    Future<http.Response> Function(http.Request request) handler, {
    List<String> filterHeaders = const [],
  }) : headersToFilter = filterHeaders,
       super(
         clientFactory: () =>
             MockClient((request) => _record(request, handler)),
       );

  /// Stores every request observed by the mock transport.
  static final List<http.Request> requests = [];

  /// Records [request] before delegating to [handler].
  static Future<http.Response> _record(
    http.Request request,
    Future<http.Response> Function(http.Request request) handler,
  ) {
    requests.add(request);
    return handler(request);
  }

  /// Lists the response headers this state carries into the next request.
  @override
  final List<String> headersToFilter;

  @override
  dynamic get serialized => data;
}

/// Builds a JSON response for the mock transport.
http.Response jsonOk(Object body, {Map<String, String> headers = const {}}) =>
    http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json', ...headers},
    );

/// [http.BaseClient] stub that records whether [close] was called.
class _CloseTrackingClient extends http.BaseClient {
  _CloseTrackingClient({required this.onClose});

  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw UnsupportedError('_CloseTrackingClient is for disposal tests only');
  }

  @override
  void close() {
    onClose();
    super.close();
  }
}

void main() {
  setUp(_TestStateAPI.requests.clear);

  group('StateAPI', () {
    group('endpoint', () {
      test('should return the base endpoint when no parameters are set', () {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));

        // Act
        state.baseEndpoint = 'https://example.com/items';

        // Assert
        expect(state.endpoint, 'https://example.com/items');
      });

      test('should merge query parameters into the endpoint', () {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        state.paginate = true;
        state.passParameters = true;

        // Act
        final endpoint = state.endpoint;

        // Assert
        expect(endpoint, contains('page=1'));
        expect(endpoint, contains('limit=10'));
      });
    });

    group('urlClear', () {
      test('should remove pagination parameters from a url', () {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));

        // Act
        final result = state.urlClear(
          'https://example.com/items?page=3&limit=50&status=active',
        );

        // Assert
        expect(result, isNot(contains('page=')));
        expect(result, isNot(contains('limit=')));
        expect(result, contains('status=active'));
      });

      test('should return null for a null url', () {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));

        // Act & Assert
        expect(state.urlClear(null), isNull);
      });
    });

    group('headersFiltered', () {
      test('should return only the exact headers requested', () {
        // Arrange
        final state = _TestStateAPI(
          (_) async => jsonOk({'id': '1'}),
          filterHeaders: ['x-keep'],
        );
        state.headers = {'X-Keep': 'yes', 'x-drop': 'no'};

        // Act
        final filtered = state.headersFiltered;

        // Assert
        expect(filtered, {'x-keep': 'yes'});
      });

      test('should support wildcard suffix matching', () {
        // Arrange
        final state = _TestStateAPI(
          (_) async => jsonOk({'id': '1'}),
          filterHeaders: ['x-custom-*'],
        );
        state.headers = {
          'X-Custom-One': '1',
          'x-custom-two': '2',
          'x-other': '3',
        };

        // Act
        final filtered = state.headersFiltered;

        // Assert
        expect(filtered, {'x-custom-one': '1', 'x-custom-two': '2'});
      });

      test('should return an empty map when nothing is configured', () {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.headers = {'x-anything': 'value'};

        // Act & Assert
        expect(state.headersFiltered, isEmpty);
      });
    });

    group('call', () {
      test('should set an error when the base endpoint is empty', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));

        // Act
        final result = await state.call();

        // Assert
        expect(result, isNull);
        expect(state.data, isNull);
        expect(state.error, 'Endpoint path is empty');
        expect(_TestStateAPI.requests, isEmpty);
      });

      test('should fetch and decode a JSON response', () async {
        // Arrange
        final state = _TestStateAPI(
          (_) async => jsonOk({'id': '1', 'name': 'first'}),
        );
        state.baseEndpoint = 'https://example.com/items';

        // Act
        final result = await state.call();

        // Assert
        expect(result, {'id': '1', 'name': 'first'});
        expect(state.data, {'id': '1', 'name': 'first'});
        expect(state.error, isNull);
        expect(state.initialized, isTrue);
        expect(state.loading, isFalse);
      });

      test('should use the configured HTTP method', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        state.method = HTTPMethod.POST;

        // Act
        await state.call();

        // Assert
        expect(_TestStateAPI.requests.single.method, 'POST');
      });

      test('should encode a Map body as JSON', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        state.method = HTTPMethod.POST;
        state.body = {'name': 'value'};

        // Act
        await state.call();

        // Assert
        final request = _TestStateAPI.requests.single;
        expect(request.body, '{"name":"value"}');
        expect(request.headers['Content-Type'], contains('application/json'));
      });

      test('should send a String body unchanged', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        state.method = HTTPMethod.POST;
        state.body = 'raw-payload';

        // Act
        await state.call();

        // Assert
        expect(_TestStateAPI.requests.single.body, 'raw-payload');
      });

      test('should record an error for an unsupported body type', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        state.method = HTTPMethod.POST;
        state.body = 42;

        // Act
        await state.call();

        // Assert
        expect(state.error, contains('Unsupported body type'));
        expect(state.errorCount, 1);
      });

      test(
        'should attach the Authorization header when authenticated',
        () async {
          // Arrange
          final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
          state.baseEndpoint = 'https://example.com/items';
          state.authScheme = AuthScheme.Bearer;
          state.credentials = 'token-123';

          // Act
          await state.call();

          // Assert
          expect(
            _TestStateAPI.requests.single.headers['Authorization'],
            'Bearer token-123',
          );
        },
      );

      test('should skip the request when credentials are incomplete', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        state.authScheme = AuthScheme.Bearer;

        // Act
        await state.call();

        // Assert
        expect(_TestStateAPI.requests, isEmpty);
        expect(state.loading, isFalse);
        expect(state.data, isNull);
      });

      test('should record an error when no content type is returned', () async {
        // Arrange
        final state = _TestStateAPI((_) async => http.Response('{}', 200));
        state.baseEndpoint = 'https://example.com/items';

        // Act
        await state.call();

        // Assert
        expect(state.error, contains('No content type found'));
        expect(state.errorCount, 1);
      });

      test('should surface the API error message from the payload', () async {
        // Arrange
        final state = _TestStateAPI(
          (_) async => http.Response(
            jsonEncode({'message': 'Not allowed'}),
            403,
            headers: {'content-type': 'application/json'},
          ),
        );
        state.baseEndpoint = 'https://example.com/items';

        // Act
        await state.call();

        // Assert
        expect(state.error, 'Not allowed');
        expect(state.errorCount, 1);
      });

      test('should stop calling after more than one error', () async {
        // Arrange
        final state = _TestStateAPI(
          (_) async => http.Response(
            jsonEncode({'message': 'boom'}),
            500,
            headers: {'content-type': 'application/json'},
          ),
        );
        state.baseEndpoint = 'https://example.com/items';

        // Act
        await state.call(ignoreDuplicatedCalls: false);
        await state.call(ignoreDuplicatedCalls: false);
        final requestsAfterFailures = _TestStateAPI.requests.length;
        await state.call(ignoreDuplicatedCalls: false);

        // Assert: the circuit breaker suppresses the third request.
        expect(state.errorCount, 2);
        expect(_TestStateAPI.requests.length, requestsAfterFailures);
      });

      test('should suppress a duplicated call for the same endpoint', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        await state.call();

        // Act
        final result = await state.call();

        // Assert
        expect(_TestStateAPI.requests, hasLength(1));
        expect(result, {'id': '1'});
      });

      test('should repeat the call when duplicates are not ignored', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        await state.call();

        // Act
        await state.call(ignoreDuplicatedCalls: false);

        // Assert
        expect(_TestStateAPI.requests, hasLength(2));
      });

      test('should read totalCount from the x-total-count header', () async {
        // Arrange
        final state = _TestStateAPI(
          (_) async => jsonOk(
            [
              {'id': '1'},
            ],
            headers: {'x-total-count': '42'},
          ),
        );
        state.baseEndpoint = 'https://example.com/items';

        // Act
        await state.call();

        // Assert
        expect(state.totalCount, 42);
      });

      test(
        'should derive totalCount from the payload when paginating',
        () async {
          // Arrange
          final state = _TestStateAPI(
            (_) async => jsonOk([
              {'id': '1'},
              {'id': '2'},
            ]),
          );
          state.paginate = true;
          state.baseEndpoint = 'https://example.com/items';

          // Act
          await state.call();

          // Assert
          expect(state.totalCount, 2);
        },
      );

      test('should publish the payload through the data stream', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        final received = <dynamic>[];
        final subscription = state.stream.listen(received.add);

        // Act
        await state.call();
        await settleDebounce();

        // Assert
        expect(received.last, {'id': '1'});
        await subscription.cancel();
      });
    });

    group('clear', () {
      test('should reset the last endpoint and headers', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        await state.call();

        // Act
        state.clear();
        await Future<void>.delayed(Duration.zero);
        await state.call();

        // Assert: clearing the cached endpoint allows a fresh request.
        expect(state.headers, isNotEmpty);
        expect(_TestStateAPI.requests, hasLength(2));
      });
    });

    group('dispose', () {
      test('should not throw when disposed without a prior call', () {
        // Arrange — positive control: dispose must succeed even when no request
        // was ever sent and no streaming subscription exists.
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));

        // Act & Assert
        expect(() => state.dispose(), returnsNormally);
      });

      test('should close the HTTP client on dispose', () {
        // Arrange
        var closeCalled = false;
        final state = _TestStateAPI(
          (_) async => jsonOk({'id': '1'}),
        );
        // Replace the client with one that records close() calls.
        state.httpClient = _CloseTrackingClient(onClose: () {
          closeCalled = true;
        });

        // Act
        state.dispose();

        // Assert — the client is closed so its connections are not leaked.
        expect(closeCalled, isTrue);
      });
    });
  });
}
