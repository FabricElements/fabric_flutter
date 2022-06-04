import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devicelocale/devicelocale.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Utils for a variety of different utility functions.
class Utils {
  /// Get Random value
  static final Random _random = Random.secure();

  /// Create Random String
  static String createCryptoRandomString([int length = 32]) {
    var values = List<int>.generate(length, (i) => _random.nextInt(256));
    return (base64Url.encode(values)).substring(1, 7);
  }

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

  /// Serialize DateTime string from JSON
  static DateTime? dateTimeFromJson(String? time) =>
      time != null ? DateTime.tryParse(time)?.toUtc() : null;

  /// Serialize DateTime to JSON string
  static String? dateTimeToJson(DateTime? time) => time != null
      ? DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(time.toUtc()).toString()
      : null;

  /// Serialize Date to JSON string (yyyy-MM-dd)
  static String? dateToJson(DateTime? time) {
    if (time == null) return null;
    return DateFormat('yyyy-MM-dd').format(time.toUtc()).toString();
  }

  /// Serialize string to double
  static double? stringToDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  /// Serialize string to int
  static int? stringToInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  /// User Presence
  /// responses: active, inactive, away
  static String getPresence(DateTime? time) {
    String _presence = 'away';
    if (time == null) return _presence;
    DateTime now = DateTime.now();
    DateTime timeInactive = now.subtract(const Duration(minutes: 2));
    DateTime timeAway = now.subtract(const Duration(minutes: 3));
    if (time.isAfter(timeInactive)) _presence = 'active';
    if (time.isBefore(timeInactive)) _presence = 'inactive';
    if (time.isBefore(timeAway)) _presence = 'away';
    return _presence;
  }

  /// Get a String path from a provided [uri] and [queryParameters]
  /// If any key value is empty the key is removed from the response
  static String uriQueryToStringPath({
    required Uri uri,
    required Map<String, List<String>> queryParameters,
  }) {
    Map<String, Iterable<String>> _parameters = {...uri.queryParametersAll};
    _parameters.addAll(queryParameters);
    _parameters.removeWhere((key, value) => value.isEmpty);
    Uri _baseUri = uri;
    _baseUri = _baseUri.replace(
      queryParameters: _parameters,
    );
    return _baseUri.toString();
  }

  static List<String>? valuesFromQueryKey(
    Map<String, List<String>>? queryParameters,
    String key,
  ) {
    if (queryParameters == null ||
        !queryParameters.containsKey(key) ||
        queryParameters[key]!.isEmpty) return null;
    return queryParameters[key];
  }

  /// Push Named path from URI query
  static void pushNamedFromQuery({
    required BuildContext context,
    required Map<String, List<String>> queryParameters,
    required Uri uri,
  }) {
    Navigator.of(context).pushNamed(uriQueryToStringPath(
      uri: uri,
      queryParameters: queryParameters,
    ));
  }

  static DateTime? dateTimeOffset({
    num? utcOffset,
    DateTime? dateTime,
    bool reverse = false,
  }) {
    if (utcOffset == null || dateTime == null) return dateTime;
    // DateTime _currentDate = dateTime.isUtc ? dateTime : dateTime.toUtc();
    DateTime _currentDate = dateTime;
    bool negativeTime = utcOffset.isNegative;
    int timeZoneOffset = utcOffset.abs().toInt();
    Duration timeZoneOffsetDuration = Duration(minutes: timeZoneOffset);

    // num timeZoneOffset = utcOffset;
    // bool positiveTime = !timeZoneOffset.isNegative;
    // timeZoneOffset = timeZoneOffset.abs();
    // Duration timeZoneOffsetDuration = Duration(minutes: timeZoneOffset.floor());

    /// Default date and time
    if (reverse) negativeTime = !negativeTime;
    DateTime updatedDate = negativeTime
        ? _currentDate.subtract(timeZoneOffsetDuration)
        : _currentDate.add(timeZoneOffsetDuration);

    /// Place time
    // _currentDate = positiveTime
    //     ? _currentDate.add(timeZoneOffsetDuration)
    //     : _currentDate.subtract(timeZoneOffsetDuration);
    return DateTime.utc(
      updatedDate.year,
      updatedDate.month,
      updatedDate.day,
      updatedDate.hour,
      updatedDate.minute,
    );
  }

  static void setPageTitle(String title) {
    SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(
      label: title,
      // primaryColor:
      //     Theme.of(context).primaryColor.value, // This line is required
    ));
  }

  /// Redirects to [path] when the value is null or empty
  /// Sample:
  /// @override
  /// void initState() {
  ///   Utils().missingValueRedirect(
  ///     context: context,
  ///     value: widget.uri.queryParameters['client'],
  ///   );
  ///   super.initState();
  /// }
  void missingValueRedirect({
    required String? value,
    required BuildContext context,
    String path = '/',
  }) {
    if (value == null || value.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.popAndPushNamed(context, path);
      });
    }
  }

  /// Get device language
  static Future<String> getLanguage() async {
    String language = 'en';
    List languages = (await Devicelocale.preferredLanguages)!;
    String baseLanguage = languages[0];
    String cleanLanguage = baseLanguage.substring(0, 2);
    if (cleanLanguage == 'es') {
      language = cleanLanguage;
    }
    return language;
  }
}
