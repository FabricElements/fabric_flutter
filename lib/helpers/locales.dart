import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

String _mergeLocales(languageCode, keyPath, Map<String, dynamic> keys) {
  RegExp regExp = new RegExp(r"([a-zA-Z0-9_-]+)");
  String finalResponse = "";
  try {
    assert(regExp.hasMatch(keyPath));
    if (keys.containsKey(keyPath)) {
      if (keys[keyPath].containsKey("en")) {
        finalResponse = keys[keyPath]["en"];
      }
      if (keys[keyPath].containsKey(languageCode)) {
        finalResponse = keys[keyPath][languageCode];
      }
    }
  } catch (error) {}
  if (finalResponse == "") {
    finalResponse = keyPath;
  }
  return finalResponse;
}

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  Map<String, dynamic> keys;

  Future<bool> load() async {
    String data = await rootBundle.loadString("assets/locales.json");
    keys = json.decode(data);
    return true;
  }

  get(String key) {
    return _mergeLocales(locale.languageCode, key, keys);
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'es'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
