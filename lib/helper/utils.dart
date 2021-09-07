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

  /// Serialize Timestamp From Json
  static DateTime timestampFromJson(Timestamp? timestamp) =>
      timestamp != null ? timestamp.toDate() : DateTime.now();

  /// Serialize Timestamp to Json
  static Timestamp timestampToJson(DateTime? time) =>
      time != null ? Timestamp.fromDate(time) : Timestamp.now();
}
