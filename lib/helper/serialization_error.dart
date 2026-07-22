import 'package:json_annotation/json_annotation.dart';

/// Converts an error thrown during JSON deserialization into a concise,
/// human-readable message.
///
/// When [error] is a [CheckedFromJsonException] (produced by models annotated
/// with `@JsonSerializable(checked: true)`), the returned message names the
/// offending key so it's clear which field is invalid, e.g.:
/// `Invalid field "id": type 'Null' is not a subtype of type 'String'`.
String serializationError(Object error) {
  if (error is CheckedFromJsonException) {
    final detail = error.message ?? error.innerError?.toString();
    final key = error.key;
    final buffer = StringBuffer();
    if (key != null) {
      buffer.write('Invalid field "$key"');
    } else if (error.className != null) {
      buffer.write('Invalid `${error.className}`');
    } else {
      buffer.write('Invalid data');
    }
    if (detail != null && detail.isNotEmpty) {
      buffer.write(': $detail');
    }
    return buffer.toString();
  }
  return error.toString();
}
