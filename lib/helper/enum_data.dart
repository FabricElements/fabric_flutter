import 'package:flutter/foundation.dart';

import 'app_localizations_delegate.dart';

/// [EnumData] provides extended support for enums
class EnumData {
  const EnumData({
    this.locales,
  });

  final AppLocalizations? locales;

  /// Get Value from enum
  static String? describe(dynamic base, {bool debug = false}) {
    String? label = debug ? 'unknown' : null;
    if (base == null) return label;
    try {
      label = describeEnum(base);
      return label;
    } catch (error) {
      //
    }
    return label;
  }

  /// Get locales from enum
  String localesFromEnum(dynamic base) {
    if (base == null) return '';
    String text = describe(base) ?? 'unknown';
    return locales != null
        ? locales!.get('label--$text')
        : 'LOCALES NOT INCLUDED';
  }

  /// Find enum match or return unknown value or null
  /// [enums] should be passed as a list == enums.values
  /// [value] expected to find
  /// [unknown] is used if there is no match
  static dynamic match({
    required List<dynamic> enums,
    required dynamic value,
    dynamic unknown,
  }) {
    assert(enums.isNotEmpty, 'enums can\'t be empty');
    if (enums.contains(value)) {
      return value;
    }
    return unknown;
  }

  /// Find enum match or return unknown value or null
  /// [enums] should be passed as a list == enums.values
  /// [value] expected to find
  /// [unknown] is used if there is no match
  static String? matchString({
    required List<dynamic> enums,
    required dynamic value,
    dynamic unknown,
  }) {
    final findMatch = match(
      enums: enums,
      value: value,
      unknown: unknown,
    );
    print('findMatch: $findMatch');
    if (findMatch == null) return null;
    return describe(findMatch);
  }

  /// Find and return enum from a given string value
  static dynamic findFromString({
    required List<dynamic> enums,
    required String? value,
  }) {
    assert(enums.isNotEmpty, 'enums can\'t be empty');
    if (value == null) return null;
    try {
      return enums.firstWhere((e) => describe(e)!.endsWith(value));
    } catch (e) {
      // - Ignore error
    }
    return null;
  }
}
