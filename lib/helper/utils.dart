import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Utils for a variety of different utility functions.
class Utils {
  static final Random _random = Random.secure();

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
}
