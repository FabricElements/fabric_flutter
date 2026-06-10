import 'package:flutter/foundation.dart';

import 'app_localizations_delegate.dart';
import 'log_color.dart';

/// Provides extended enum manipulation and localization utilities.
///
/// This helper simplifies enum-to-string conversion, reverse lookups, and
/// locale-aware label resolution for application enums. Methods support both
/// modern Dart enhanced enums and legacy enum patterns.
class EnumData {
  const EnumData({this.locales});

  final AppLocalizations? locales;

  /// Converts an enum value into its string name representation.
  ///
  /// Returns the name portion after the last dot, or the entire string for
  /// legacy enum types. When [debug] is `true` and [base] is `null`, returns
  /// `'unknown'` instead of `null` to simplify debugging flows.
  static String? describe(dynamic base, {bool debug = false}) {
    String? label = debug ? 'unknown' : null;
    if (base == null) return label;
    try {
      if (base is Enum) {
        label = base.name;
      } else {
        label = base.toString();
      }
    } catch (error) {
      label = base.tostring();
    }
    if (label != null && label.contains('.')) {
      label = label.split('.').last;
    }
    return label;
  }

  /// Returns a localized label for the provided enum [base].
  ///
  /// Converts [base] to its string key via [describe], then looks up the
  /// localized string from [locales]. Returns an error message when [locales]
  /// is not configured.
  String localesFromEnum(dynamic base) {
    if (base == null) return '';
    String text = describe(base) ?? 'unknown';
    return locales != null
        ? locales!.get('label--$text')
        : 'LOCALES NOT INCLUDED';
  }

  /// Searches [enums] for [value] and returns it, or [unknown] if not found.
  ///
  /// This method performs an identity check against the provided enum list.
  /// Use [unknown] to supply a fallback value when the caller needs a typed
  /// default instead of `null`.
  static dynamic match({
    required List<Enum> enums,
    required dynamic value,
    dynamic unknown,
  }) {
    assert(enums.isNotEmpty, 'enums can\'t be empty');
    if (enums.contains(value)) {
      return value;
    }
    return unknown;
  }

  /// Searches [enums] for [value] and returns its string name or [unknown].
  ///
  /// This convenience wrapper calls [match] followed by [describe] to produce a
  /// human-readable string. Returns `null` when no match is found and [unknown]
  /// is not provided.
  static String? matchString({
    required List<Enum> enums,
    required dynamic value,
    dynamic unknown,
  }) {
    final findMatch = match(enums: enums, value: value, unknown: unknown);
    if (findMatch == null) return null;
    return describe(findMatch);
  }

  /// Finds the first enum in [enums] whose [describe] output matches [value].
  ///
  /// Returns `null` when [value] is `null` or no match is found. This method is
  /// useful for deserializing strings back into typed enum constants.
  static Enum? findFromString({
    required List<Enum> enums,
    required String? value,
  }) {
    assert(enums.isNotEmpty, 'enums can\'t be empty');
    if (value == null) return null;
    try {
      return enums.firstWhere((e) => describe(e) == value);
    } catch (e) {
      // - Ignore error
    }
    return null;
  }

  /// Locates an enum in [enums] by identity or string-name match against [value].
  ///
  /// Attempts an identity match first via [match], then falls back to comparing
  /// string names. Returns `null` when both strategies fail. Errors are logged
  /// via [debugPrint] to help diagnose mismatched enum definitions.
  static Enum? find({required List<Enum> enums, required dynamic value}) {
    if (value == null) return null;
    dynamic finalValue;
    String? error;
    try {
      /// Find from enum
      finalValue = match(enums: enums, value: value, unknown: null);
    } catch (e) {
      error = '!!!! Find from enum: $e';
    }
    if (finalValue == null) {
      /// Find from string value
      try {
        finalValue = enums.firstWhere((e) => describe(e) == describe(value));
      } catch (e) {
        error = '!!!! Find from string: $e';
      }
    }
    if (finalValue == null && error != null) {
      debugPrint(LogColor.error('EnumData.find: $error'));
    }
    return finalValue;
  }

  /// Converts a list of enum values into their string names.
  ///
  /// Returns a list of non-null string names extracted via [describe]. Useful
  /// for populating dropdowns, filter chips, or serialized configuration.
  static List<String> toList(List<Enum> enums) {
    return enums.map((e) => describe(e)!).toList();
  }
}
