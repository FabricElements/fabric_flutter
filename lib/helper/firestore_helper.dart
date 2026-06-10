import 'package:cloud_firestore/cloud_firestore.dart';

/// Provides Firestore timestamp serialization and type-conversion utilities.
///
/// These helpers normalize timestamps from multiple sources (native Firestore,
/// Node.js Firestore Admin SDK, ISO strings, and raw [DateTime] objects) into
/// a consistent [Timestamp] or [DateTime] representation for storage and
/// transport.
class FirestoreHelper {
  /// Converts various timestamp representations into a Firestore [Timestamp].
  ///
  /// Accepts native [Timestamp] objects, Node.js Admin SDK maps with `_seconds`
  /// and `_nanoseconds` keys, [DateTime] instances, and ISO 8601 date strings.
  /// Returns `null` when [data] cannot be parsed into a valid timestamp.
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

  /// Deserializes a timestamp from JSON and falls back to the current time.
  ///
  /// Calls [timestampFromJsonMap] to parse [timestamp], then converts the
  /// result to UTC. When parsing fails or [timestamp] is `null`, returns the
  /// current UTC time so required timestamp fields always receive a valid value.
  static DateTime timestampFromJsonDefault(dynamic timestamp) =>
      (timestampFromJsonMap(timestamp)?.toDate() ?? DateTime.now()).toUtc();

  /// Deserializes a timestamp from JSON without a fallback.
  ///
  /// Calls [timestampFromJsonMap] to parse [timestamp], then converts the
  /// result to UTC. Returns `null` when parsing fails so optional timestamp
  /// fields remain absent rather than defaulting to a synthetic value.
  static DateTime? timestampFromJson(dynamic timestamp) =>
      timestampFromJsonMap(timestamp)?.toDate().toUtc();

  /// Serializes a [DateTime] into a Firestore [Timestamp] with a fallback.
  ///
  /// Converts [time] to UTC before creating the [Timestamp]. When [time] is
  /// `null`, returns the current server time so required timestamp fields
  /// always receive a value during serialization.
  static Timestamp timestampToJsonDefault(DateTime? time) =>
      time != null ? Timestamp.fromDate(time.toUtc()) : Timestamp.now();

  /// Serializes a [DateTime] into a Firestore [Timestamp] without a fallback.
  ///
  /// Converts [time] to UTC before creating the [Timestamp]. Returns `null`
  /// when [time] is `null` so optional timestamp fields remain absent.
  static Timestamp? timestampToJson(DateTime? time) =>
      time != null ? Timestamp.fromDate(time.toUtc()) : null;

  /// Ignores [time] and returns the current server timestamp.
  ///
  /// Use this serializer for `updatedAt` or `modifiedAt` fields that should
  /// reflect the exact time of the write operation rather than a caller-supplied
  /// value.
  static Timestamp? timestampUpdate(DateTime? time) => Timestamp.now();

  /// Converts `null` values into Firestore delete sentinels.
  ///
  /// Returns [value] unchanged when it is non-null, or [FieldValue.delete] when
  /// [value] is `null`. Use with `@JsonKey(toJson: ...)` to remove fields from
  /// documents instead of storing explicit nulls.
  static dynamic notNullToJson(dynamic value) => value ?? FieldValue.delete();

  /// Strips [FieldValue] sentinels during deserialization.
  ///
  /// Returns [value] unchanged unless it is a [FieldValue], in which case this
  /// method returns `null`. Prevents client-side sentinel objects from leaking
  /// into deserialized models.
  static dynamic ignoreFieldValue(dynamic value) =>
      value is FieldValue ? null : value;
}
