import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/iso_language.dart';
import '../helper/options.dart';
import '../serialized/iso_data.dart';
import 'input_data.dart';

/// Builds a language picker for selecting an ISO 639-1 code.
///
/// The widget wraps [InputData] so callers can reuse the shared dropdown UI
/// while choosing from [ISOLanguage] entries. Set [voice] to `true` to limit
/// the options to languages supported by WaveNet voice resources, and use
/// [onChange] to keep parent state synchronized with the selected code.
///
/// ```dart
/// LanguagePicker(
///   voice: false,
///   value: 'es',
///   onChange: (String? iso) {
///     selectedLanguage = iso;
///   },
/// );
/// ```
class LanguagePicker extends StatelessWidget {
  /// Creates a language picker wired to the shared [InputData] dropdown UI.
  ///
  /// The picker keeps widget code focused on storing the selected ISO code while
  /// the component handles localization, optional voice filtering, and default
  /// labels.
  const LanguagePicker({
    super.key,
    this.voice = false,
    this.value = 'en',
    this.label,
    this.hintText,
    this.disabled = false,
    required this.onChange,
  });

  /// Determines whether the picker only shows languages with WaveNet support.
  ///
  /// When `true`, the dropdown filters [ISOLanguages.languages] to entries whose
  /// alpha-2 code appears in [ISOLanguages.waveNetLanguages].
  final bool voice;

  /// Stores the currently selected ISO 639-1 language code.
  ///
  /// The picker falls back to `'en'` through the constructor when callers do not
  /// supply a value.
  final String? value;

  /// Reports the newly selected language code back to the parent widget.
  ///
  /// The callback receives the chosen alpha-2 code or `null` when the selection
  /// is cleared.
  final Function(String?) onChange;

  /// Stores a custom placeholder shown before a value is selected.
  ///
  /// When `null`, the widget uses a localized prompt from
  /// [AppLocalizationsDelegate].
  final String? hintText;

  /// Stores a custom field label for the dropdown.
  ///
  /// When `null`, the widget uses the localized language label from
  /// [AppLocalizationsDelegate].
  final String? label;

  /// Determines whether the picker prevents user interaction.
  ///
  /// Disabled pickers still display the current selection so forms remain
  /// readable in review-only states.
  final bool disabled;

  /// Builds the localized dropdown and keeps the option list in sync with [voice].
  ///
  /// The widget converts each [ISOLanguage] entry into a [ButtonOptions] item so
  /// [InputData] can render a localized dropdown with consistent package styling.
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
      hintText:
          hintText ??
          locales.get('label--choose-label', {
            'label': locales.get('label--language'),
          }),
      value: value,
      type: InputDataType.dropdown,
      options: options,
      onChanged: (dynamic value) => onChange(value as String?),
      disabled: disabled,
    );
  }
}
