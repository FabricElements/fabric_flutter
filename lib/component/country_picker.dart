import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/iso_countries.dart';
import '../helper/options.dart';
import '../serialized/iso_data.dart';
import 'input_data.dart';

/// A Picker used to select a country by it's alpha2 code
///
/// [value] This is the country alpha2 code, it will default to us.
/// [onChange] This will push selected language iso to parent widget to sync with campaign data.
/// ```dart
/// CountryPicker(
///   value: 'US',
///   onChange: (String iso) {
///     selectedCountry = iso;
///   }
/// );
/// ```
class CountryPicker extends StatelessWidget {
  const CountryPicker({
    super.key,
    this.value = 'US',
    this.phoneNumberOrigin = false,
    this.label,
    this.hintText,
    this.disabled = false,
    required this.onChange,
  });

  final String? value;
  final Function(String?) onChange;
  final String? hintText;
  final String? label;
  final bool disabled;
  final bool phoneNumberOrigin;

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
      prefixIcon: const Icon(Icons.flag),
      label: label ?? locales.get('label--country'),
      hintText: hintText ??
          locales.get(
              'label--choose-label', {'label': locales.get('label--country')}),
      value: value,
      type: InputDataType.dropdown,
      options: options,
      onChanged: (dynamic value) => onChange(value as String?),
      isExpanded: true,
      disabled: disabled,
    );
  }
}
