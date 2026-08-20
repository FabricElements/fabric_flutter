import 'dart:async';

import 'package:fabric_flutter/variables.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../placeholder/default_locales.dart';
import 'log_color.dart';

/// Resolves translated labels from the package's localization maps.
///
/// This class merges application-provided translations with the bundled
/// fallback labels from [defaultLocales]. It also normalizes incoming keys so
/// callers can request labels from widgets, helpers, and error handlers using a
/// consistent API.
class AppLocalizations {
  /// Creates a localization resolver for [locale].
  AppLocalizations(this.locale);

  /// Identifies the active locale used when selecting translated strings.
  final Locale locale;

  /// Validates that a key path contains at least one usable token.
  ///
  /// Compiled once and reused so [_mergeLocales] does not rebuild it on every
  /// lookup, which happens for essentially every localized label in the tree.
  static final RegExp _keyPathExp = RegExp(r'([a-zA-Z\d_-]+)');

  /// Matches `{placeholder}` tokens when substituting option values.
  ///
  /// Shared across calls to [_replaceOptions] to avoid recompiling the pattern
  /// on every message that carries options.
  static final RegExp _placeholderExp = RegExp(r'{.*?}');

  /// Strips characters that are not valid in a normalized key.
  ///
  /// Reused by [get] instead of being recompiled on each invocation.
  static final RegExp _invalidCharsExp = RegExp(r'([^a-zA-Z\d-]+)');

  /// Detects camelCase boundaries so they can be split with a dash.
  ///
  /// Reused by [get] instead of being recompiled on each invocation.
  static final RegExp _camelCaseExp = RegExp(r'(?<=[a-z])[A-Z]');

  /// Returns whether an [AppLocalizations] instance is available in [context].
  ///
  /// This private guard lets [of] fall back to English when localization state
  /// has not been wired into the widget tree yet, which is especially helpful in
  /// tests and early app bootstrap code.
  static bool _isLocalizationsDefined(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) !=
        null;
  }

  /// Returns the active localization resolver for [context].
  ///
  /// When no resolver has been provided through [Localizations], this returns a
  /// temporary English instance so callers can still obtain predictable labels.
  static AppLocalizations of(BuildContext context) {
    if (_isLocalizationsDefined(context)) {
      return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
    }
    return AppLocalizations(const Locale('en', 'US'));
  }

  /// Stores translations keyed by localization id and language code.
  ///
  /// Consumers can inject custom labels into [keys], and [load] fills in any
  /// missing entries from the package defaults so lookups remain resilient.
  Map<String, Map<String, String>> keys = {};

  /// Merges [defaultLocales] into [keys] and reports when initialization ends.
  ///
  /// Missing translation groups are added lazily so custom locale maps only need
  /// to override the labels they care about.
  Future<bool> load() async {
    /// Add missing locales
    for (var entry in defaultLocales.entries) {
      keys.putIfAbsent(entry.key, () => entry.value);
    }
    return true;
  }

  /// Resolves [keyPath] against custom labels and bundled fallbacks.
  ///
  /// English is used as the intermediate fallback before trying the active
  /// [locale.languageCode], and the original key is returned when no translation
  /// exists. That behavior makes missing labels visible during development while
  /// still keeping the app functional.
  String _mergeLocales(String keyPath) {
    String finalResponse = '';
    try {
      assert(_keyPathExp.hasMatch(keyPath));
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

  /// Replaces `{placeholder}` tokens in [text] with values from [options].
  ///
  /// Unknown placeholders are left untouched so partially populated option maps
  /// do not destroy the surrounding message. Errors are logged and ignored to
  /// keep localization lookup non-fatal.
  String _replaceOptions(String text, Map<String, String> options) {
    String result = text;
    Iterable matches = _placeholderExp.allMatches(text);
    if (matches.isNotEmpty) {
      for (var match in matches) {
        try {
          String tag = text.substring(match.start, match.end);
          String cleanTag = tag.substring(1, tag.length - 1);
          String? replaceWith = options[cleanTag];
          if (replaceWith != null) {
            // Pass the tag as a plain string so it is replaced literally. This
            // avoids allocating a RegExp per placeholder and treats regex
            // metacharacters (like `{` or `}`) as literal text.
            result = result.replaceAll(tag, replaceWith);
          }
        } catch (e) {
          // Ensure we pass a string to the logger.
          debugPrint(LogColor.warning(e.toString()));
        }
      }
    }
    return result;
  }

  /// Returns the localized label for [key], optionally applying [options].
  ///
  /// Keys are normalized before lookup so callers can pass values with
  /// underscores, camelCase, or extra punctuation and still resolve the intended
  /// `label--...` entry. When a key cannot be found, the normalized key itself is
  /// returned, and debug builds log the missing translation to make gaps easier
  /// to spot.
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
      keyFinal = keyFinal.replaceAll(_invalidCharsExp, '');
    } catch (e) {
      //
    }
    try {
      // Handle camelCase
      keyFinal = keyFinal.replaceAllMapped(
        _camelCaseExp,
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

/// Loads [AppLocalizations] instances for the widget tree.
///
/// The delegate accepts custom locale maps from the host application and blends
/// them with the package defaults during [load].
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  /// Creates a delegate backed by [locales].
  const AppLocalizationsDelegate({required this.locales});

  /// Supplies custom translation maps that should be merged at load time.
  final Map<String, Map<String, String>> locales;

  /// Reports that any locale can be requested because fallback labels exist.
  @override
  bool isSupported(Locale locale) => true; // every language is supported

  /// Creates and initializes an [AppLocalizations] instance for [locale].
  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    localizations.keys = {...locales};
    await localizations.load();
    return localizations;
  }

  /// Returns `false` because the delegate is immutable once constructed.
  ///
  /// Avoiding reloads prevents unnecessary localization work during rebuilds.
  @override
  bool shouldReload(AppLocalizationsDelegate old) => false; // false to prevent loading every time a widget is build
}
