import 'dart:async';

import 'package:fabric_flutter/variables.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../placeholder/default_locales.dart';
import 'log_color.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  /// Verify if the localizations are defined on the context
  /// [context] the context to verify
  /// Returns true if the localizations are defined
  static bool _isLocalizationsDefined(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) !=
        null;
  }

  static AppLocalizations of(BuildContext context) {
    if (_isLocalizationsDefined(context)) {
      return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
    }
    return AppLocalizations(const Locale('en', 'US'));
  }

  /// The keys of the locales
  /// Assign custom labels to the keys
  Map<String, Map<String, String>> keys = {};

  /// Load custom locales and add add missing labels
  Future<bool> load() async {
    /// Add missing locales
    for (var entry in defaultLocales.entries) {
      keys.putIfAbsent(entry.key, () => entry.value);
    }
    return true;
  }

  /// Merge the default locales with the custom locales
  String _mergeLocales(String keyPath) {
    RegExp regExp = RegExp(r'([a-zA-Z\d_-]+)');
    String finalResponse = '';
    try {
      assert(regExp.hasMatch(keyPath));
      if (keys.containsKey(keyPath)) {
        if (keys[keyPath]!.containsKey('en')) {
          finalResponse = keys[keyPath]!['en']!;
        }
        if (keys[keyPath]!.containsKey(locale.languageCode)) {
          finalResponse = keys[keyPath]![locale.languageCode]!;
        }
      }
    } catch (error) {
      //
    }
    if (finalResponse == '') {
      finalResponse = keyPath;
    }
    return finalResponse;
  }

  /// Replace the options in the string
  String _replaceOptions(String text, Map<String, String> options) {
    String result = text;
    RegExp regExp = RegExp(r'{.*?}');
    Iterable matches = regExp.allMatches(text);
    if (matches.isNotEmpty) {
      for (var match in matches) {
        try {
          String tag = text.substring(match.start, match.end);
          String cleanTag = tag.substring(1, tag.length - 1);
          RegExp regExpTag = RegExp(r'' + tag + '', multiLine: true);
          String? replaceWith = options[cleanTag];
          if (replaceWith != null) {
            result = result.replaceAll(regExpTag, replaceWith);
          }
        } catch (e) {
          debugPrint(LogColor.warning(e));
        }
      }
    }
    return result;
  }

  /// Get Locale from key and options
  /// [key] the locale key. It will be cleaned and fixed as needed
  /// [options] the locale optional values that will be replaced
  String get(dynamic key, [Map<String, String>? options]) {
    // Return same value if it doesn't contain a --- string
    if (key != null && !key.toString().contains('--')) {
      return key;
    }
    String keyFinal = key?.toString() ?? 'label--unknown';
    // Fix dash
    keyFinal = keyFinal.replaceAll('_', '-');
    try {
      // Remove invalid characters
      RegExp regExp = RegExp(r'([^a-zA-Z\d-]+)');
      keyFinal = keyFinal.replaceAll(regExp, '');
    } catch (e) {
      //
    }
    try {
      // Handle camelCase
      RegExp exp = RegExp(r'(?<=[a-z])[A-Z]');
      keyFinal = keyFinal.replaceAllMapped(
        exp,
        (Match m) => ('-${m.group(0)!}'),
      );
    } catch (e) {
      //
    }
    keyFinal = keyFinal.toLowerCase();
    String finalLocalization = _mergeLocales(keyFinal);
    if (options != null) {
      finalLocalization = _replaceOptions(finalLocalization, options);
    }
    // Check if the key is not found
    if (!kIsTest && kDebugMode && finalLocalization == keyFinal) {
      debugPrint(
        LogColor.warning('AppLocalizations: Missing Localization - $keyFinal'),
      );
    }
    return finalLocalization;
  }
}

/// The localizations delegate
/// This class is used to load the localizations
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate({required this.locales});

  /// The locales to load
  final Map<String, Map<String, String>> locales;

  @override
  bool isSupported(Locale locale) => true; // every language is supported

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    localizations.keys = {...locales};
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false; // false to prevent loading every time a widget is build
}
