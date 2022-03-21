import 'package:flutter/cupertino.dart';

import '../helper/iso_language.dart';

/// A Picker used to select wanted language for campaign
///
/// [voice] Dictates whether the campaign is using voice calls or text messages.
/// [language] This is the language of the campaign, it will default to english.
/// [onChange] This will push selected language iso to parent widget to sync with campaign data.
/// ```dart
/// LanguageSelector(
///   voice: false,
///   language: 'es',
///   onChange: (String iso) {
///     selectedLanguage = iso;
///   }
/// );
/// ```
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    Key? key,
    this.voice = false,
    this.language = 'en',
    this.onChange,
  }) : super(key: key);
  final bool voice;
  final String? language;
  final Function? onChange;

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
          languages.add(Text(isoLanguages[key]['name']));
          isoList.add(key);
        }
      }
    } else {
      for (String key in isoLanguages.keys) {
        languages.add(Text(isoLanguages[key]['name']));
        isoList.add(key);
      }
    }
    String defaultLanguage = language ?? 'en';
    index = isoList.indexOf(defaultLanguage.toLowerCase());
    return CupertinoPicker(
      scrollController: FixedExtentScrollController(initialItem: index),
      children: languages,
      itemExtent: 32,
      onSelectedItemChanged: (int scrollIndex) {
        onChange!(isoList[scrollIndex]);
      },
    );
  }
}
