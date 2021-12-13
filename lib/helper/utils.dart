import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Utils for a variety of different utility functions.
class Utils {
  static final Random _random = Random.secure();

  /// Create Random String
  static String createCryptoRandomString([int length = 32]) {
    var values = List<int>.generate(length, (i) => _random.nextInt(256));
    return (base64Url.encode(values)).substring(1, 7);
  }

  /// Serialize Timestamp From Json with default value
  static DateTime timestampFromJsonDefault(Timestamp? timestamp) =>
      timestamp?.toDate() ?? DateTime.now();

  /// Serialize Timestamp From Json
  static DateTime? timestampFromJson(Timestamp? timestamp) =>
      timestamp?.toDate();

  /// Serialize Timestamp to Json with default value
  static Timestamp timestampToJsonDefault(DateTime? time) =>
      time != null ? Timestamp.fromDate(time) : Timestamp.now();

  /// Serialize Timestamp to Json
  static Timestamp? timestampToJson(DateTime? time) =>
      time != null ? Timestamp.fromDate(time) : null;

  /// Serialize DateTime string from JSON
  static DateTime? dateTimeFromJson(String? time) =>
      time != null ? DateTime.tryParse(time) : null;

  /// Serialize DateTime to JSON string
  static String? dateTimeToJson(DateTime? time) => time != null
      ? DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(time).toString()
      : null;

  /// Serialize Date to JSON string (yyyy-MM-dd)
  static String? dateToJson(DateTime? time) {
    if (time == null) return null;
    return DateFormat("yyyy-MM-dd").format(time).toString();
  }

  /// User Presence
  /// responses: active, inactive, away
  static String getPresence(DateTime? time) {
    String _presence = "away";
    if (time == null) return _presence;
    DateTime now = DateTime.now();
    DateTime timeInactive = now.subtract(Duration(minutes: 2));
    DateTime timeAway = now.subtract(Duration(minutes: 3));
    if (time.isAfter(timeInactive)) _presence = "active";
    if (time.isBefore(timeInactive)) _presence = "inactive";
    if (time.isBefore(timeAway)) _presence = "away";
    return _presence;
  }

  /// Get a String path from a provided [uri] and [queryParameters]
  /// If any key value is empty the key is removed from the response
  static String uriQueryToStringPath({
    required Uri uri,
    required Map<String, String> queryParameters,
  }) {
    Map<String, String> _parameters = {...uri.queryParameters};
    _parameters.addAll(queryParameters);
    _parameters.removeWhere((key, value) => value.isEmpty);
    Uri _baseUri = uri;
    _baseUri = _baseUri.replace(
      queryParameters: _parameters,
    );
    return _baseUri.toString();
  }
}
