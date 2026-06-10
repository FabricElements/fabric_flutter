import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/iso_countries.dart';
import '../helper/options.dart';
import '../serialized/iso_data.dart';
import 'input_data.dart';

/// Builds a country selector from the bundled ISO country dataset.
///
/// The widget composes [InputData] so country selection matches the package's
/// broader form styling while still exposing country-specific labels and
/// filtering. When [phoneNumberOrigin] is `true`, it limits choices to entries
/// supported by the phone helper dataset so downstream phone-origin workflows
/// only receive compatible values.
class CountryPicker extends StatelessWidget {
  /// Creates a country picker backed by ISO alpha-2 country codes.
  ///
  /// The picker defaults to `'US'` and forwards selection changes through
  /// [onChange]. Callers can override the localized label and hint text, or
  /// disable interaction with [disabled].
  const CountryPicker({
    super.key,
    this.value = 'US',
    this.phoneNumberOrigin = false,
    this.label,
    this.hintText,
    this.disabled = false,
    required this.onChange,
  });

  /// Stores the selected ISO alpha-2 country code.
  ///
  /// The value defaults to `'US'` when omitted so the field starts from a
  /// common country selection while still allowing `null` when callers clear it.
  final String? value;

  /// Receives the newly selected country code.
  ///
  /// The callback provides a nullable [String] so [InputData] can propagate a
  /// cleared dropdown selection as `null`.
  final Function(String?) onChange;

  /// Stores the placeholder text shown before selection.
  ///
  /// When `null`, the widget falls back to the localized choose-country prompt
  /// from [AppLocalizations].
  final String? hintText;

  /// Stores the field label displayed above the selector.
  ///
  /// When `null`, the widget uses the localized country label from
  /// [AppLocalizations].
  final String? label;

  /// Determines whether the selector accepts user interaction.
  ///
  /// When `true`, the widget continues showing the current [value] while
  /// preventing edits.
  final bool disabled;

  /// Determines whether the selector only shows phone-supported countries.
  ///
  /// When `true`, the widget filters [ISOCountries.countries] against
  /// [ISOCountries.phoneSupportedCountries] before building the dropdown.
  final bool phoneNumberOrigin;

  /// Builds the localized dropdown used to select a country.
  ///
  /// The widget resolves labels through [BuildContext], converts each
  /// [ISOCountry] into a [ButtonOptions] entry, and forwards changes to
  /// [onChange].
  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    List<ISOCountry> items = ISOCountries.countries;
    if (phoneNumberOrigin) {
      // Filter available voices by those available on WaveNet
      items = items.where((element) {
        return ISOCountries.phoneSupportedCountries.contains(element.alpha2);
      }).toList();
    }
    // List of iso's corresponding to the text widgets
    List<ButtonOptions> options = List.generate(items.length, (index) {
      final item = items[index];
      return ButtonOptions(
        label: '${item.flag} ${item.name} (${item.alpha2})',
        labelAlt: item.fullName,
        value: item.alpha2,
      );
    });
    return InputData(
      autofillHints: const [],
      prefixIcon: const Icon(Icons.flag),
      label: label ?? locales.get('label--country'),
      hintText: hintText ??
          locales.get('label--choose-label', {
            'label': locales.get('label--country'),
          }),
      value: value,
      type: InputDataType.dropdown,
      options: options,
      onChanged: (dynamic value) => onChange(value as String?),
      disabled: disabled,
    );
  }
}
