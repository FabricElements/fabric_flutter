import 'package:flutter/cupertino.dart';

import './input_data.dart';
import '../helper/app_localizations_delegate.dart';
import '../helper/iso_language.dart';
import '../helper/options.dart';
import '../serialized/iso_data.dart';

/// A Picker used to select wanted language for campaign
///
/// [voice] Dictates whether the campaign is using voice calls or text messages.
/// [value] This is the language of the campaign, it will default to english.
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
    this.value = 'en',
    this.label,
    this.hintText,
    required this.onChange,
  }) : super(key: key);
  final bool voice;
  final String? value;
  final Function(String?) onChange;
  final String? hintText;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context)!;
    // List of iso's corresponding to the text widgets
    List<ISOLanguage> languages = ISOLanguages.languages;
    if (voice) {
      // Filter available voices by those available on WaveNet
      languages = languages.where((element) {
        return ISOLanguages.waveNetLanguages.contains(element.alpha2);
      }).toList();
    }
    List<ButtonOptions> options = List.generate(languages.length, (index) {
      final language = languages[index];
      return ButtonOptions(
        label: '${language.emoji} ${language.name} (${language.alpha2})',
        value: language.alpha2,
      );
    });
    return InputData(
      label: label ?? locales.get('label--language'),
      hintText: hintText ??
          locales.get(
              'label--choose-label', {'label': locales.get('label--language')}),
      value: value,
      type: InputDataType.dropdown,
      options: options,
      onChanged: (dynamic value) => onChange(value as String?),
      isExpanded: true,
    );
  }
}
