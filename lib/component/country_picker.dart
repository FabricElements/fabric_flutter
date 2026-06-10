import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/iso_countries.dart';
import '../helper/options.dart';
import '../serialized/iso_data.dart';
import 'input_data.dart';

/// Lets users choose a country from the bundled ISO country dataset.
///
/// The widget wraps [InputData] so country selection stays visually consistent with the
/// rest of the form system while still exposing specialized country labels and filtering.
/// When [phoneNumberOrigin] is enabled it narrows the list to regions supported by the
/// phone helper dataset, which avoids offering values that downstream phone formatting
/// cannot handle reliably.
class CountryPicker extends StatelessWidget {
  /// Creates a country picker backed by ISO alpha-2 country codes.
  const CountryPicker({
    super.key,
    this.value = 'US',
    this.phoneNumberOrigin = false,
    this.label,
    this.hintText,
    this.disabled = false,
    required this.onChange,
  });

  /// Holds the selected ISO alpha-2 country code, defaulting to `'US'` when omitted.
  final String? value;
  /// Receives the newly selected country code, or `null` when the selection is cleared.
  final Function(String?) onChange;
  /// Overrides the default localized placeholder shown before a country is chosen.
  final String? hintText;
  /// Overrides the default localized field label.
  final String? label;
  /// Disables interaction while still displaying the current country value.
  final bool disabled;
  /// Restricts options to countries supported by phone-origin features when `true`.
  final bool phoneNumberOrigin;

  /// Builds the underlying dropdown field with localized country labels and flags.
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
      hintText:
          hintText ??
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
