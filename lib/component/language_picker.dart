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
class LanguagePicker extends StatefulWidget {
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
    this.semanticsLabel,
    this.automationKey,
    this.semanticHint,
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

  /// Overrides the accessibility label exposed to screen readers and agents.
  ///
  /// Forwarded unchanged to the underlying [InputData.semanticsLabel].
  final String? semanticsLabel;

  /// Assigns a deterministic automation identifier to the picker.
  ///
  /// Forwarded unchanged to the underlying [InputData.automationKey].
  final String? automationKey;

  /// Provides a structural, non-visual hint for the picker.
  ///
  /// Forwarded unchanged to the underlying [InputData.semanticHint].
  final String? semanticHint;

  /// Creates the mutable state that memoizes the language options.
  @override
  State<LanguagePicker> createState() => _LanguagePickerState();
}

/// Holds the pre-built dropdown options for [LanguagePicker].
///
/// The option list is derived from the bundled ISO dataset once in
/// [initState] instead of on every build, because it depends only on the
/// immutable [LanguagePicker.voice] flag.
class _LanguagePickerState extends State<LanguagePicker> {
  /// Caches the dropdown options built from the ISO language dataset.
  late final List<ButtonOptions> _options;

  /// Builds the language options once from the bundled ISO dataset.
  @override
  void initState() {
    super.initState();
    List<ISOLanguage> items = ISOLanguages.languages;
    if (widget.voice) {
      // Filter available voices by those available on WaveNet
      items = items.where((element) {
        return ISOLanguages.waveNetLanguages.contains(element.alpha2);
      }).toList();
    }
    // List of iso's corresponding to the text widgets
    _options = List.generate(items.length, (index) {
      final item = items[index];
      return ButtonOptions(
        label: '${item.emoji} ${item.name} (${item.alpha2})',
        labelAlt: item.nativeName,
        value: item.alpha2,
      );
    });
  }

  /// Builds the localized dropdown using the pre-built [_options].
  ///
  /// The widget forwards changes to [LanguagePicker.onChange] while resolving
  /// labels through [BuildContext].
  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    return InputData(
      prefixIcon: const Icon(Icons.language),
      label: widget.label ?? locales.get('label--language'),
      hintText:
          widget.hintText ??
          locales.get('label--choose-label', {
            'label': locales.get('label--language'),
          }),
      value: widget.value,
      type: InputDataType.dropdown,
      options: _options,
      onChanged: (dynamic value) => widget.onChange(value as String?),
      disabled: widget.disabled,
      semanticsLabel: widget.semanticsLabel,
      automationKey: widget.automationKey,
      semanticHint: widget.semanticHint,
    );
  }
}
