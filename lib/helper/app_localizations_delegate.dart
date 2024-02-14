import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../placeholder/default_locales.dart';

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
  Map<String, dynamic> keys = {};

  /// Load the locales from the assets
  Future<bool> load() async {
    try {
      String data = await rootBundle.loadString('assets/locales.json');
      keys = json.decode(data);
    } catch (e) {
      if (kDebugMode) {
        print('Unable to load locales file from path assets/locales.json');
      }
    }

    /// Add missing locales
    defaultLocales.forEach((key, value) => keys.putIfAbsent(key, () => value));
    return true;
  }

  /// Merge the default locales with the asset locales
  String _mergeLocales(String keyPath) {
    RegExp regExp = RegExp(r'([a-zA-Z\d_-]+)');
    String finalResponse = '';
    try {
      assert(regExp.hasMatch(keyPath));
      if (keys.containsKey(keyPath)) {
        if (keys[keyPath].containsKey('en')) {
          finalResponse = keys[keyPath]['en'];
        }
        if (keys[keyPath].containsKey(locale.languageCode)) {
          finalResponse = keys[keyPath][locale.languageCode];
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
          debugPrint(e.toString());
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
      keyFinal =
          keyFinal.replaceAllMapped(exp, (Match m) => ('-${m.group(0)!}'));
    } catch (e) {
      //
    }
    keyFinal = keyFinal.toLowerCase();
    String finalLocalization = _mergeLocales(keyFinal);
    if (options != null) {
      finalLocalization = _replaceOptions(finalLocalization, options);
    }
    return finalLocalization;
  }
}

/// The localizations delegate
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true; // every language is supported

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) =>
      false; // false to prevent loading every time a widget is build
}
