import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../helpers/iso-language.dart';

/// A Picker used to select wanted language for campaign
///
/// [voice] Dictates whether the campaign is using voice calls or text messages.
/// [language] This is the language of the campaign, it will default to english.
/// [onChange] This will push selected language iso to parent widget to sync with campaign data.
/// [pickerTextColor] Customize the picker text color with a Color variable, defaults to white.
/// ```dart
/// LanguageSelector(
///   voice: false,
///   language: "es",
///   onChange: (String iso) {
///     selectedLanguage = iso;
///   }
/// );
/// ```
class LanguageSelector extends StatelessWidget {
  LanguageSelector({
    Key key,
    this.backgroundColor = const Color(0xFF161A21),
    this.voice = false,
    this.language = "en",
    this.onChange,
    this.pickerTextColor = Colors.white,
  }) : super(key: key);
  final Color backgroundColor;
  final bool voice;
  final String language;
  final Function onChange;
  final Color pickerTextColor;

  @override
  Widget build(BuildContext context) {
    int index = 0;
    Map<String, dynamic> isoLanguages = IsoLanguage().isoLanguages;
    // List of text widgets for the picker
    List<Text> languages = [];
    // List of iso's corresponding to the text widgets
    List<String> isoList = [];
    if (voice) {
      // Filter available voices by those available on WaveNet
      List waveNetLanguages = IsoLanguage().waveNetLanguages;
      for (String key in isoLanguages.keys) {
        if (waveNetLanguages.contains(key)) {
          languages.add(Text(isoLanguages[key]["name"]));
          isoList.add(key);
        }
      }
    } else {
      for (String key in isoLanguages.keys) {
        languages.add(Text(isoLanguages[key]["name"]));
        isoList.add(key);
      }
    }
    String defaultLanguage = language ?? "en";
    index = isoList.indexOf(defaultLanguage.toLowerCase());
    CupertinoThemeData cupertinoTheme = CupertinoTheme.of(context);
    return CupertinoTheme(
      data: cupertinoTheme.copyWith(
          textTheme: cupertinoTheme.textTheme.copyWith(
              pickerTextStyle: cupertinoTheme.textTheme.pickerTextStyle
                  .copyWith(color: pickerTextColor))),
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(initialItem: index),
        backgroundColor: backgroundColor,
        children: languages,
        itemExtent: 32,
        onSelectedItemChanged: (int scrollIndex) {
          onChange(isoList[scrollIndex] ?? "en");
        },
      ),
    );
  }
}
