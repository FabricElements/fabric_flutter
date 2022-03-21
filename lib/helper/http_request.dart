/// https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication#authentication_schemes
enum AuthScheme {
  // ignore: constant_identifier_names
  Basic,
  // ignore: constant_identifier_names
  Bearer,
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
}
