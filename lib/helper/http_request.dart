import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart';

/// Enumerates the supported HTTP authentication schemes.
///
/// These values map directly to the scheme prefix used in an `Authorization`
/// header and mirror the terminology defined by MDN.
/// https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication#authentication_schemes
///
enum AuthScheme {
  /// Uses base64-encoded username and password credentials.
  // ignore: constant_identifier_names
  Basic,

  /// Uses a bearer token provided by the server or identity provider.
  // ignore: constant_identifier_names
  Bearer,

  /// Uses a JSON Web Token prefix for APIs that expect `JWT` explicitly.
  // TODO: Remove after it's implemented
  // ignore: constant_identifier_names
  JWT,
}

/// Enumerates the HTTP methods supported by this helper.
///
/// The values match the standard HTTP verbs described by MDN and can be reused
/// by higher-level networking helpers when building requests.
/// https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods
///
enum HTTPMethod {
  /// Requests only response headers for a resource.
  HEAD,

  /// Retrieves a resource without modifying server state.
  GET,

  /// Creates a resource or submits data for processing.
  POST,

  /// Replaces an existing resource with a full new representation.
  PUT,

  /// Applies a partial update to an existing resource.
  PATCH,

  /// Removes a resource.
  DELETE,
}

/// Builds common HTTP authentication headers and response helpers.
///
/// This utility keeps low-level networking code consistent by centralizing how
/// authorization headers are formatted and how error responses are interpreted.
class HTTPRequest {
  /// Creates an [HTTPRequest] helper.
  ///
  /// When either [credentials] or [authScheme] is provided, both must be set so
  /// the helper can build a valid `Authorization` header.
  const HTTPRequest({this.credentials, this.authScheme})
    : assert(
        credentials != null || authScheme != null
            ? credentials != null && authScheme != null
            : true,
        'token and authScheme are required for Authentication',
      );

  /// Stores the raw credentials used to build an `Authorization` header.
  ///
  /// The meaning depends on [authScheme], such as a base64-encoded user pair or
  /// a bearer token returned by an authentication service.
  /// See https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication.
  final String? credentials;

  /// Declares how [credentials] should be labeled in the header.
  ///
  /// Use [AuthScheme.Bearer] for most token-based APIs unless the backend
  /// explicitly expects another scheme.
  /// See https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication#authentication_schemes.
  final AuthScheme? authScheme;

  /// Returns the fully formatted `Authorization` header value, if available.
  ///
  /// The returned string combines [authScheme] and [credentials], or `null`
  /// when authentication was not configured for the request.
  String? get formattedCredentials => credentials != null && authScheme != null
      ? '${authScheme.toString().split('.').last} $credentials'
      : null;

  /// Returns the headers contributed by this helper.
  ///
  /// The map is empty when no authentication was configured, which allows
  /// callers to merge it into other headers without special handling.
  Map<String, String> get headers {
    Map<String, String> endHeaders = {};
    if (formattedCredentials != null) {
      endHeaders.addAll({'Authorization': formattedCredentials!});
    }
    return endHeaders;
  }

  /// Throws when [response] indicates the caller is not authenticated.
  ///
  /// This helper isolates authorization failures so callers can handle `401`
  /// and `403` responses distinctly from general server or validation errors.
  static void authenticated(Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw 'error--${response.statusCode}';
    }
  }

  /// Throws a best-effort error message extracted from [response].
  ///
  /// Successful `2xx` responses return normally. For failures, the helper looks
  /// for a JSON `message`, then a JSON `errors` list, then the HTTP reason
  /// phrase, and finally falls back to an `error--statusCode` key.
  static void error(Response response) {
    /// Accept status code from 200 to 299
    if (response.statusCode >= 200 && response.statusCode <= 299) {
      return;
    }

    /// Catch Reason Phrase
    String? errorResponse;

    /// Catch Error Message from JSON response
    try {
      final responseObject = jsonDecodeAndClean(response.body);
      errorResponse = responseObject['message']?.toString();
    } catch (e) {
      //--
    }
    if (errorResponse != null) throw errorResponse;

    /// Catch Error Message List from JSON response
    try {
      Map<String, dynamic> responseObject = jsonDecodeAndClean(response.body);
      if (responseObject.containsKey('errors')) {
        final errors = responseObject['errors'] as List<dynamic>;
        if (errors.isNotEmpty) {
          if (errors.first.containsKey('description')) {
            errorResponse = errors
                .map((e) => e['description'])
                .toList()
                .join(', ');
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

  /// Decodes JSON from [data] and removes empty top-level values.
  ///
  /// Maps have `null` and empty-string entries removed, while lists drop `null`
  /// and empty-string items. Non-collection JSON values are returned unchanged.
  static dynamic jsonDecodeAndClean(dynamic data) {
    final decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) {
      decoded.removeWhere(
        (key, value) => value == null || (value is String && value.isEmpty),
      );
      return decoded;
    }
    if (decoded is List) {
      return decoded
          .where((e) => !(e == null || (e is String && e.isEmpty)))
          .toList();
    }
    return decoded;
  }

  /// Returns the parsed body from [response] after validating it.
  ///
  /// The helper first delegates to [error]. Empty bodies become `null`, JSON
  /// bodies are decoded with [jsonDecodeAndClean], and all other payloads are
  /// returned as plain text.
  static dynamic response(Response response) {
    /// Check for errors
    error(response);

    /// Check for empty response
    if (response.body.isEmpty) {
      return null;
    }

    /// Get response depending on content type
    final contentType = response.headers['content-type'];
    if (contentType != null &&
        (contentType.contains('application/json') ||
            contentType.contains('application/x-json-stream'))) {
      return jsonDecodeAndClean(response.body);
    }
    return response.body;
  }
}
