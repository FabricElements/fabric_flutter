import 'dart:convert';
import 'dart:math';

import 'package:devicelocale/devicelocale.dart';
import 'package:fabric_flutter/serialized/user_data.dart';
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

  /// Serialize Timestamp to Json: Used to apply the latest time on every update
  static bool boolFalse(dynamic value) => false;

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
  static UserPresence getPresence(DateTime? time) {
    UserPresence value = UserPresence.away;
    if (time == null) return value;
    DateTime now = DateTime.now();
    DateTime timeInactive = now.subtract(const Duration(minutes: 2));
    DateTime timeAway = now.subtract(const Duration(minutes: 3));
    if (time.isAfter(timeInactive)) value = UserPresence.active;
    if (time.isBefore(timeInactive)) value = UserPresence.inactive;
    if (time.isBefore(timeAway)) value = UserPresence.away;
    return value;
  }

  /// Get name abbreviation
  static String nameFromParts({String? firstName, String? lastName}) {
    String finalName = '';
    if (firstName != null && firstName.isNotEmpty) {
      finalName += firstName;
    }
    if (lastName != null && lastName.isNotEmpty) {
      finalName += ' ';
      finalName += lastName;
    } else {
      finalName += '.';
    }
    return finalName;
  }

  /// Get name abbreviation
  static String nameAbbreviation({String? firstName, String? lastName}) {
    String finalName = '';
    if (firstName != null || lastName != null) {
      if (firstName != null && firstName.isNotEmpty) {
        finalName += firstName[0];
      }
      if (lastName != null && lastName.isNotEmpty) {
        finalName += lastName[0];
      } else {
        finalName += '.';
      }
    }
    return finalName.toUpperCase();
  }

  /// Get a String path from a provided [uri] and [queryParameters]
  /// If any key value is empty the key is removed from the response
  static Uri uriMergeQuery({
    required Uri uri,
    required Map<String, List<String>> queryParameters,
  }) {
    final qp = mergeQueryParameters(uri.queryParametersAll, queryParameters);
    Uri baseUri = uri;
    baseUri = baseUri.replace(
      queryParameters: qp,
    );
    return baseUri;
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
    Navigator.of(context).pushNamed(uriMergeQuery(
      uri: uri,
      queryParameters: queryParameters,
    ).toString());
  }

  static DateTime? dateTimeOffset({
    num? utcOffset,
    DateTime? dateTime,
    bool reverse = false,
  }) {
    if (utcOffset == null || dateTime == null) return dateTime;
    DateTime currentDate = dateTime.toUtc();
    bool negativeTime = utcOffset.isNegative;
    int timeZoneOffset = utcOffset.abs().toInt();
    Duration timeZoneOffsetDuration = Duration(minutes: timeZoneOffset);
    if (reverse) negativeTime = !negativeTime;

    /// Default date and time
    DateTime updatedDate = negativeTime
        ? currentDate.subtract(timeZoneOffsetDuration)
        : currentDate.add(timeZoneOffsetDuration);

    return updatedDate;
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
  ///   Utils.missingValueRedirect(
  ///     context: context,
  ///     value: widget.uri.queryParameters['client'],
  ///   );
  ///   super.initState();
  /// }
  static void missingValueRedirect({
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
    try {
      List languages = (await Devicelocale.preferredLanguages)!;
      String baseLanguage = languages[0];
      String cleanLanguage = baseLanguage.substring(0, 2);
      if (cleanLanguage == 'es') {
        language = cleanLanguage;
      }
    } catch (e) {
      /// Only works when method si supported
    }

    return language;
  }

  /// Merge two sets of query parameters and clean empty ones
  static Map<String, List<String>> mergeQueryParameters(
    // base parameters
    Map<String, List<String>> base,
    // Parameters to merge
    Map<String, List<String>> toReplace,
  ) {
    Map<String, List<String>> qp = {
      ...base,
    };
    // Remove sql parameter
    qp.remove('sql');
    // Remove pagination
    qp.remove('page');
    qp.remove('limit');
    // Remove key and value if exist
    qp.removeWhere((key, value) => toReplace.containsKey(key));
    // Merge filters
    qp = {
      ...qp,
      ...toReplace,
    };
    // Remove empty values
    qp.removeWhere((key, value) {
      return value.isEmpty || (value.isNotEmpty && value.first.isEmpty);
    });
    // Return new query parameters
    return qp;
  }
}
