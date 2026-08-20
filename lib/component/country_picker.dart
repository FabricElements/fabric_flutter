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
class CountryPicker extends StatefulWidget {
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
    this.semanticsLabel,
    this.automationKey,
    this.semanticHint,
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

  /// Overrides the accessibility label exposed to screen readers and agents.
  ///
  /// Forwarded unchanged to the underlying [InputData.semanticsLabel].
  final String? semanticsLabel;

  /// Assigns a deterministic automation identifier to the selector.
  ///
  /// Forwarded unchanged to the underlying [InputData.automationKey].
  final String? automationKey;

  /// Provides a structural, non-visual hint for the selector.
  ///
  /// Forwarded unchanged to the underlying [InputData.semanticHint].
  final String? semanticHint;

  /// Creates the mutable state that memoizes the country options.
  @override
  State<CountryPicker> createState() => _CountryPickerState();
}

/// Holds the pre-built dropdown options for [CountryPicker].
///
/// The option list is derived from the bundled ISO dataset once in
/// [initState] instead of on every build, because it depends only on the
/// immutable [CountryPicker.phoneNumberOrigin] flag.
class _CountryPickerState extends State<CountryPicker> {
  /// Caches the dropdown options built from the ISO country dataset.
  late final List<ButtonOptions> _options;

  /// Builds the country options once from the bundled ISO dataset.
  @override
  void initState() {
    super.initState();
    List<ISOCountry> items = ISOCountries.countries;
    if (widget.phoneNumberOrigin) {
      // Filter available countries by those supported for phone origins.
      items = items.where((element) {
        return ISOCountries.phoneSupportedCountries.contains(element.alpha2);
      }).toList();
    }
    // List of iso's corresponding to the text widgets
    _options = List.generate(items.length, (index) {
      final item = items[index];
      return ButtonOptions(
        label: '${item.flag} ${item.name} (${item.alpha2})',
        labelAlt: item.fullName,
        value: item.alpha2,
      );
    });
  }

  /// Builds the localized dropdown used to select a country.
  ///
  /// The widget resolves labels through [BuildContext] and forwards changes to
  /// [CountryPicker.onChange] using the pre-built [_options].
  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    return InputData(
      autofillHints: const [],
      prefixIcon: const Icon(Icons.flag),
      label: widget.label ?? locales.get('label--country'),
      hintText:
          widget.hintText ??
          locales.get('label--choose-label', {
            'label': locales.get('label--country'),
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
