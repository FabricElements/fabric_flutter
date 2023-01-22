import 'package:cloud_firestore/cloud_firestore.dart';

/// Utils for a variety of different utility functions.
class FirestoreHelper {
  /// Serialize Timestamp From Json with default value
  static DateTime timestampFromJsonDefault(Timestamp? timestamp) =>
      (timestamp?.toDate() ?? DateTime.now()).toUtc();

  /// Serialize Timestamp From Json
  static DateTime? timestampFromJson(Timestamp? timestamp) =>
      timestamp?.toDate().toUtc();

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
}
