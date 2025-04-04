import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/iso_language.dart';
import '../helper/options.dart';
import '../serialized/iso_data.dart';
import 'input_data.dart';

/// A Picker used to select a language by it's alpha2 code
///
/// [voice] Dictates whether the campaign is using voice calls or text messages.
/// [value] This is the language alpha2 code, it will default to english.
/// [onChange] This will push selected language iso to parent widget to sync with campaign data.
/// ```dart
/// LanguagePicker(
///   voice: false,
///   value: 'es',
///   onChange: (String iso) {
///     selectedLanguage = iso;
///   }
/// );
/// ```
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    super.key,
    this.voice = false,
    this.value = 'en',
    this.label,
    this.hintText,
    this.disabled = false,
    required this.onChange,
  });

  final bool voice;
  final String? value;
  final Function(String?) onChange;
  final String? hintText;
  final String? label;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    List<ISOLanguage> items = ISOLanguages.languages;
    if (voice) {
      // Filter available voices by those available on WaveNet
      items = items.where((element) {
        return ISOLanguages.waveNetLanguages.contains(element.alpha2);
      }).toList();
    }
    // List of iso's corresponding to the text widgets
    List<ButtonOptions> options = List.generate(items.length, (index) {
      final item = items[index];
      return ButtonOptions(
        label: '${item.emoji} ${item.name} (${item.alpha2})',
        labelAlt: item.nativeName,
        value: item.alpha2,
      );
    });
    return InputData(
      prefixIcon: const Icon(Icons.language),
      label: label ?? locales.get('label--language'),
      hintText: hintText ??
          locales.get(
              'label--choose-label', {'label': locales.get('label--language')}),
      value: value,
      type: InputDataType.dropdown,
      options: options,
      onChanged: (dynamic value) => onChange(value as String?),
      disabled: disabled,
    );
  }
}
