import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../placeholder/default_locales.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  Map<String, dynamic> keys = {};

  Future<bool> load() async {
    try {
      String data = await rootBundle.loadString("assets/locales.json");
      keys = json.decode(data);
    } catch (e) {
      print("Unable to load locales file from path assets/locales.json");
    }

    /// Add missing locales
    defaultLocales.forEach((key, value) => keys.putIfAbsent(key, () => value));
    return true;
  }

  String _mergeLocales(keyPath) {
    RegExp regExp = new RegExp(r"([a-zA-Z0-9_-]+)");
    String finalResponse = "";
    try {
      assert(regExp.hasMatch(keyPath));
      if (keys.containsKey(keyPath)) {
        if (keys[keyPath].containsKey("en")) {
          finalResponse = keys[keyPath]["en"];
        }
        if (keys[keyPath].containsKey(locale.languageCode)) {
          finalResponse = keys[keyPath][locale.languageCode];
        }
      }
    } catch (error) {}
    if (finalResponse == "") {
      finalResponse = keyPath;
    }
    return finalResponse;
  }

  String _replaceOptions(String text, Map<String, String> options) {
    String result = text;
    RegExp regExp = new RegExp(
      r"{(?:.*?)}",
      multiLine: true,
    );
    RegExp _regexBrackets = new RegExp(
      r"{}",
      multiLine: true,
    );

    Iterable matches = regExp.allMatches(text);
    if (matches.length > 0) {
      matches.forEach((match) {
        try {
          String tag = text.substring(match.start, match.end);
          String cleanTag = tag.substring(1, tag.length - 1);
          RegExp _regExp = new RegExp(
            r"" + tag + "",
            multiLine: true,
          );
          String? replaceWith = options[cleanTag];
          if (replaceWith != null) {
            result = result.replaceAll(_regExp, replaceWith);
          }
        } catch (e) {
          print(e);
        }
      });
    }
    return result;
  }

  String get(String key, [Map<String, String>? options]) {
    String finalLocalization = _mergeLocales(key);
    if (options != null) {
      finalLocalization = _replaceOptions(finalLocalization, options);
    }
    return finalLocalization;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  // bool isSupported(Locale locale) => ['en', 'es'].contains(locale.languageCode);
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
