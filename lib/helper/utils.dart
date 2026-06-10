import 'dart:convert';
import 'dart:math';

import 'package:devicelocale/devicelocale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../serialized/user_data.dart';
import 'enum_data.dart';
import 'log_color.dart';

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
  static String? dateTimeToJson(DateTime? time) =>
      time?.toUtc().toIso8601String();

  /// Serialize Date to JSON string (yyyy-MM-dd)
  static String? dateToJson(DateTime? time) {
    if (time == null) return null;
    return DateFormat('yyyy-MM-dd').format(time.toUtc()).toString();
  }

  /// Converts a string value to a double, returning null if conversion fails.
  ///
  /// Safely parses any value to double by first converting it to a string,
  /// then attempting double parsing. Returns null if the value is null or
  /// cannot be parsed as a valid double.
  static double? stringToDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  /// Converts a string value to an integer, returning null if conversion fails.
  ///
  /// Safely parses any value to int by first converting it to a string,
  /// then attempting integer parsing. Returns null if the value is null or
  /// cannot be parsed as a valid integer.
  static int? stringToInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  /// Determines user presence status based on last activity time.
  ///
  /// Evaluates [time] against current time thresholds to classify user presence:
  /// - Active: last activity within 2 minutes
  /// - Inactive: last activity between 2-4 minutes ago
  /// - Away: last activity more than 4 minutes ago or time is null
  ///
  /// Used throughout the application to display real-time user availability
  /// indicators and manage presence-based features.
  static UserPresence getPresence(DateTime? time) {
    UserPresence value = UserPresence.away;
    if (time == null) return value;
    DateTime now = DateTime.now();
    DateTime timeInactive = now.subtract(const Duration(minutes: 2));
    DateTime timeAway = now.subtract(const Duration(minutes: 4));
    if (time.isAfter(timeInactive)) value = UserPresence.active;
    if (time.isBefore(timeInactive)) value = UserPresence.inactive;
    if (time.isBefore(timeAway)) value = UserPresence.away;
    return value;
  }

  /// Constructs a full name from first and last name components.
  ///
  /// Returns a properly formatted name string from [firstName] and [lastName].
  /// If only first name is provided, appends a period. If both are provided,
  /// separates them with a space. Returns an empty string if both are null.
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

  /// Creates initials or abbreviation from first and last name.
  ///
  /// Generates a two-character abbreviation by taking the first character of
  /// [firstName] and [lastName]. If lastName is not provided, appends a period.
  /// Returns an empty string if both names are null. The result is always
  /// uppercase for consistency.
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

  /// Constructs a [Uri] by merging existing query parameters with new ones.
  ///
  /// Takes an existing [uri] and its [queryParameters], merges them using
  /// [mergeQueryParameters], and returns a new Uri with the combined query string.
  /// Empty or null values are automatically filtered out to maintain clean URLs.
  static Uri uriMergeQuery({
    required Uri uri,
    required Map<String, List<String>> queryParameters,
  }) {
    final qp = mergeQueryParameters(uri.queryParametersAll, queryParameters);
    Uri baseUri = uri;
    baseUri = baseUri.replace(queryParameters: qp);
    return baseUri;
  }

  /// Extracts the first value from query parameters for a given key.
  ///
  /// Safely retrieves query parameter values, returning null if the key doesn't
  /// exist, the query parameters map is null, or the value list is empty.
  /// Otherwise returns the list of values for that key.
  static List<String>? valuesFromQueryKey(
    Map<String, List<String>>? queryParameters,
    String key,
  ) {
    if (queryParameters == null ||
        !queryParameters.containsKey(key) ||
        queryParameters[key]!.isEmpty) {
      return null;
    }
    return queryParameters[key];
  }

  /// Navigates to a new route by merging query parameters with the current URI.
  ///
  /// Combines the existing [uri] with new [queryParameters], then navigates using
  /// the Flutter Navigator. When [pop] is true, uses `popAndPushNamed` to replace
  /// the current route instead of stacking a new one.
  ///
  /// This is particularly useful for maintaining URL state in web applications
  /// while updating specific query parameters.
  static void pushNamedFromQuery({
    required BuildContext context,
    required Map<String, List<String>> queryParameters,
    required Uri uri,
    bool pop = false,
  }) {
    final newPath = uriMergeQuery(
      uri: uri,
      queryParameters: queryParameters,
    ).toString();
    if (pop) {
      Navigator.of(context).popAndPushNamed(newPath);
    } else {
      Navigator.of(context).pushNamed(newPath);
    }
  }

  // Get the value using the time zone offset in minutes
  /// Adjusts a [DateTime] by applying a timezone offset in minutes.
  ///
  /// This helper converts between UTC and local times when the timezone offset
  /// is known in minutes. The [utcOffset] represents the number of minutes ahead
  /// (positive) or behind (negative) UTC. When [reverse] is true, the operation
  /// is inverted to convert from local time back to UTC.
  ///
  /// Returns null if [utcOffset] or [dateTime] is null, or if [utcOffset] is zero.
  static DateTime? dateTimeOffset({
    int? utcOffset,
    DateTime? dateTime,
    bool reverse = false,
  }) {
    if (utcOffset == null || dateTime == null || utcOffset == 0) {
      return dateTime;
    }
    DateTime currentDate = dateTime.toUtc();
    Duration timeZoneOffsetDuration = Duration(minutes: utcOffset.abs());
    bool offsetIsPositive = utcOffset >= 0;
    if (offsetIsPositive) {
      if (reverse) {
        return currentDate.subtract(timeZoneOffsetDuration);
      } else {
        return currentDate.add(timeZoneOffsetDuration);
      }
    } else {
      if (reverse) {
        return currentDate.add(timeZoneOffsetDuration);
      } else {
        return currentDate.subtract(timeZoneOffsetDuration);
      }
    }
  }

  /// Sets the application title displayed in the system task switcher.
  ///
  /// On supported platforms, this updates the label shown when users view
  /// running apps in the system's app switcher or overview screen.
  static void setPageTitle(String title) {
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: title,
        // primaryColor:
        //     Theme.of(context).primaryColor.value, // This line is required
      ),
    );
  }

  /// Redirects to [path] when the value is null or empty
  /// Sample:
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   Utils.missingValueRedirect(
  ///     context: context,
  ///     value: widget.uri.queryParameters['client'],
  ///   );
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

  /// Retrieves the device's preferred language code.
  ///
  /// Attempts to detect the device's language settings and returns a two-letter
  /// language code (e.g., 'en', 'es'). Currently supports English ('en') and
  /// Spanish ('es'), defaulting to 'en' for all other languages or if detection
  /// fails. Uses the devicelocale package to access system preferences.
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

  /// Merges two sets of query parameters and removes empty entries.
  ///
  /// Takes [base] query parameters and merges them with [toReplace] parameters.
  /// Any keys present in [toReplace] will override the same keys in [base].
  /// Empty values (empty strings or empty lists) are automatically removed from
  /// the final result, ensuring clean URL generation.
  ///
  /// This is useful for maintaining URL state while allowing selective updates
  /// to query parameters during navigation.
  static Map<String, List<String>> mergeQueryParameters(
    // base parameters
    Map<String, List<String>> base,
    // Parameters to merge
    Map<String, List<String>> toReplace,
  ) {
    Map<String, List<String>> qp = {...base};
    // Remove key and value if exist
    qp.removeWhere((key, value) => toReplace.containsKey(key));
    // Merge filters
    qp = {...qp, ...toReplace};
    // Remove empty values
    qp.removeWhere((key, value) {
      return value.isEmpty || (value.isNotEmpty && value.first.isEmpty);
    });
    // Return new query parameters
    return qp;
  }

  /// Retrieves the appropriate Material icon for a given status value.
  ///
  /// Maps status strings (e.g., 'draft', 'active', 'archived') to corresponding
  /// Material Design icons. The status value is converted to a string and
  /// lowercased before matching. Returns a default circle icon for unrecognized
  /// status values.
  static IconData statusIcon(dynamic value) {
    late IconData iconData;
    final finalValue = EnumData.describe(value)?.toLowerCase();
    switch (finalValue) {
      case 'draft':
        iconData = Icons.circle;
        break;
      case 'review':
        iconData = Icons.remove_red_eye;
        break;
      case 'approved':
        iconData = Icons.check_circle;
        break;
      case 'rejected':
        iconData = Icons.warning;
        break;
      case 'inactive':
        iconData = Icons.toggle_off;
        break;
      case 'paused':
        iconData = Icons.pause_circle;
        break;
      case 'scheduled':
        iconData = Icons.schedule;
        break;
      case 'active':
        iconData = Icons.toggle_on;
        break;
      case 'archived':
        iconData = Icons.archive;
        break;
      case 'suspended':
        iconData = Icons.error;
        break;
      default:
        iconData = Icons.circle;
    }
    return iconData;
  }

  /// Retrieves the appropriate Material color for a given status value.
  ///
  /// Maps status strings (e.g., 'draft', 'active', 'archived') to Material
  /// theme colors that visually represent the status. The status value is
  /// converted to a string and lowercased before matching. Returns a default
  /// grey color for unrecognized status values.
  static Color statusColor(dynamic value) {
    late Color statusColor;
    final finalValue = EnumData.describe(value)?.toLowerCase();
    switch (finalValue) {
      case 'draft':
        statusColor = Colors.blueGrey.shade600;
        break;
      case 'review':
        statusColor = Colors.amber.shade800;
        break;
      case 'approved':
        statusColor = Colors.deepPurple.shade500;
        break;
      case 'rejected':
        statusColor = Colors.red.shade500;
        break;
      case 'inactive':
        statusColor = Colors.blueGrey.shade800;
        break;
      case 'paused':
        statusColor = Colors.deepOrange.shade500;
        // statusColor = Colors.amber.shade500;
        break;
      case 'scheduled':
        statusColor = Colors.deepPurple.shade500;
        break;
      case 'active':
        statusColor = Colors.teal.shade600;
        break;
      case 'archived':
        statusColor = Colors.grey.shade900;
        break;
      case 'suspended':
        statusColor = Colors.red.shade500;
        break;
      default:
        statusColor = Colors.grey.shade800;
    }
    return statusColor;
  }

  /// Prints debug information about the widget hierarchy.
  ///
  /// Traverses up the widget tree from the given [context] and logs information
  /// about the current widget and its immediate parent, including keys and
  /// runtime types. Useful for debugging layout issues or understanding the
  /// widget tree structure during development.
  static void getParentWidgetName(BuildContext context) {
    Element? element = context as Element;

    // Move up one level in the tree
    element.visitAncestorElements((ancestor) {
      debugPrint(
        LogColor.info('''
This widget:
- key: ${element.widget.key}
- type: ${element.widget.runtimeType}
Parent widget:
- key: ${ancestor.widget.key}
-type: ${ancestor.widget.runtimeType}
-----------------------------------
      '''),
      );
      return false; // Stop after the first ancestor
    });
  }
}
