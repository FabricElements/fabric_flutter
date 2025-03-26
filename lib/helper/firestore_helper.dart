import 'package:cloud_firestore/cloud_firestore.dart';

/// Utils for a variety of different utility functions.
class FirestoreHelper {
  /// Handle timestamp from Firestore and Node Firestore responses
  /// Returns a Timestamp
  static Timestamp? timestampFromJsonMap(dynamic data) {
    Timestamp? timestamp;
    if (data is Timestamp) {
      timestamp = data;
    } else if (data is Map) {
      timestamp = Timestamp(data['_seconds'], data['_nanoseconds']);
    } else if (data is DateTime) {
      timestamp = Timestamp.fromDate(data);
    } else if (data is String) {
      final baseDate = DateTime.tryParse(data);
      timestamp = baseDate != null ? Timestamp.fromDate(baseDate) : null;
    }
    return timestamp;
  }

  /// Serialize Timestamp From Json with default value
  static DateTime timestampFromJsonDefault(dynamic timestamp) =>
      (timestampFromJsonMap(timestamp)?.toDate() ?? DateTime.now()).toUtc();

  /// Serialize Timestamp From Json
  static DateTime? timestampFromJson(dynamic timestamp) =>
      timestampFromJsonMap(timestamp)?.toDate().toUtc();

  /// Serialize Timestamp to Json with default value
  static Timestamp timestampToJsonDefault(DateTime? time) =>
      time != null ? Timestamp.fromDate(time.toUtc()) : Timestamp.now();

  /// Serialize Timestamp to Json
  static Timestamp? timestampToJson(DateTime? time) =>
      time != null ? Timestamp.fromDate(time.toUtc()) : null;

  /// Serialize Timestamp to Json: Used to apply the latest time on every update
  static Timestamp? timestampUpdate(DateTime? time) => Timestamp.now();

  /// Return null value or delete field
  static dynamic notNullToJson(dynamic value) => value ?? FieldValue.delete();

  /// Ignore value if it is FieldValue
  static dynamic ignoreFieldValue(dynamic value) =>
      value is FieldValue ? null : value;
}
