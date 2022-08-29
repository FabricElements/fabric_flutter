import 'dart:convert';

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

  /// Throw an error if it's found or null if it's ok
  static error(Response r) {
    /// Accept status code from 200 to 299
    if (r.statusCode >= 200 && r.statusCode <= 299) {
      return;
    }

    /// Catch Reason Phrase
    String? errorResponse = r.reasonPhrase != null && r.reasonPhrase!.isNotEmpty
        ? r.reasonPhrase
        : null;

    /// Catch Error Message from JSON response
    try {
      Map<String, dynamic> responseObject = jsonDecode(r.body);
      print(responseObject);
      if (responseObject.containsKey('message') &&
          (responseObject['message'] as String).isNotEmpty) {
        errorResponse = responseObject['message'];
      }
    } catch (e) {
      //--
    }

    /// Use status code if error is null
    errorResponse ??= 'error--${r.statusCode}';

    /// Throw error
    throw errorResponse;
  }

  /// Return decoded request response
  static dynamic response(Response r) {
    /// Check for errors
    error(r);

    /// Get response
    return jsonDecode(r.body);
  }
}
