import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart';

/// https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication#authentication_schemes
enum AuthScheme {
  // ignore: constant_identifier_names
  Basic,
  // ignore: constant_identifier_names
  Bearer,
  // TODO: Remove after it's implemented
  // ignore: constant_identifier_names
  JWT,
}

class HTTPRequest {
  const HTTPRequest({
    this.credentials,
    this.authScheme,
  }) : assert(
            credentials != null || authScheme != null
                ? credentials != null && authScheme != null
                : true,
            'token and authScheme are required for Authentication');

  /// [credentials]
  /// https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication
  final String? credentials;

  /// [authScheme]
  /// https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication#authentication_schemes
  /// Use Bearer for token authentication
  final AuthScheme? authScheme;

  /// Get formatted credentials
  String? get formattedCredentials => credentials != null && authScheme != null
      ? '${authScheme.toString().split('.').last} $credentials'
      : null;

  /// Get headers
  Map<String, String> get headers {
    Map<String, String> _headers = {};
    if (formattedCredentials != null) {
      _headers.addAll({'Authorization': formattedCredentials!});
    }
    return _headers;
  }

  /// Throw an error if response return a 401 response
  static authenticated(Response response) {
    if (response.statusCode >= 400 && response.statusCode <= 599) {
      throw 'error--${response.statusCode}';
    }
  }

  /// Throw an error if it's found or null if it's ok
  static error(Response response) {
    /// Accept status code from 200 to 299
    if (response.statusCode >= 200 && response.statusCode <= 299) {
      return;
    }

    /// Catch Reason Phrase
    String? errorResponse;

    /// Catch Error Message from JSON response
    try {
      final responseObject = jsonDecode(response.body);
      errorResponse = responseObject['message']?.toString();
    } catch (e) {
      //--
    }
    if (errorResponse != null) throw errorResponse;

    /// Catch Error Message List from JSON response
    try {
      Map<String, dynamic> responseObject = jsonDecode(response.body);
      if (responseObject.containsKey('errors')) {
        final errors = responseObject['errors'] as List<dynamic>;
        if (errors.isNotEmpty) {
          if (errors.first.containsKey('description')) {
            errorResponse =
                errors.map((e) => e['description']).toList().join(', ');
          }
        }
      } else {
        debugPrint(responseObject.toString());
      }
    } catch (e) {
      //--
    }
    if (errorResponse != null) throw errorResponse;

    /// Get default reasonPhrase
    errorResponse =
        response.reasonPhrase != null && response.reasonPhrase!.isNotEmpty
            ? response.reasonPhrase
            : null;
    if (errorResponse != null) throw errorResponse;

    /// Use status code if error is null
    errorResponse ??= 'error--${response.statusCode}';

    /// Throw error
    throw errorResponse;
  }

  /// Return decoded request response
  static dynamic response(Response response) {
    /// Check for errors
    error(response);

    /// Get response
    return jsonDecode(response.body);
  }
}
