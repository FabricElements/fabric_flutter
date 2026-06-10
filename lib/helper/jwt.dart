import 'dart:convert';

/// Parses a JavaScript Web Token and extracts its payload claims.
///
/// Validates that [token] contains the expected three base64url-encoded segments
/// separated by dots, then decodes and deserializes the middle segment. Throws
/// an [Exception] when the token format is invalid or the payload is not a JSON
/// object.
Map<String, dynamic> parseJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw Exception('invalid token');
  }

  final payload = _decodeBase64(parts[1]);
  final payloadMap = json.decode(payload);
  if (payloadMap is! Map<String, dynamic>) {
    throw Exception('invalid payload');
  }

  return payloadMap;
}

/// Decodes a base64url-encoded string into UTF-8 text.
///
/// Converts URL-safe base64 characters back to standard base64 format and adds
/// the required padding before decoding. Throws an [Exception] when [str] is
/// not a valid base64url string.
String _decodeBase64(String str) {
  String output = str.replaceAll('-', '+').replaceAll('_', '/');

  switch (output.length % 4) {
    case 0:
      break;
    case 2:
      output += '==';
      break;
    case 3:
      output += '=';
      break;
    default:
      throw Exception('Illegal base64url string!');
  }

  return utf8.decode(base64Url.decode(output));
}
