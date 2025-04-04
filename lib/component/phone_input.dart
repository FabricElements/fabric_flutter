import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/input_validation.dart';
import '../helper/iso_countries.dart';
import '../helper/options.dart';
import '../serialized/iso_data.dart';
import 'input_data.dart';

class PhoneInput extends StatefulWidget {
  const PhoneInput({
    super.key,
    required this.onChanged,
    required this.value,
    this.disabled = false,
    this.country,
  });

  final Function(String?) onChanged;
  final String? value;
  final bool disabled;
  final String? country;

  @override
  State<PhoneInput> createState() => _PhoneInputState();
}

class _PhoneInputState extends State<PhoneInput> {
  PhoneNumberUtil phoneUtil = PhoneNumberUtil.instance;
  int? callingCode;
  ISOCountry? country;
  int? phoneNumber;

  /// Format the input string to extract the country code and phone number
  formatInput(String input) {
    List<ISOCountry> items = ISOCountries.countries;
    try {
      PhoneNumber parsedNumber =
          phoneUtil.parse(input, widget.country?.toUpperCase() ?? 'US');
      callingCode = parsedNumber.countryCode;
      phoneNumber = parsedNumber.nationalNumber.toInt();
      country = items.firstWhere(
          (element) => element.callingCode == callingCode.toString());
      if (mounted) setState(() {});
    } on NumberParseException catch (e) {
      debugPrint('NumberParseException was thrown: ${e.toString()}');
    }
    if (callingCode == null) {}
  }

  getCountryData() {
    if (country == null && widget.country != null) {
      final match = ISOCountries.countries
          .where((element) => element.alpha2 == widget.country!.toUpperCase());
      if (match.isNotEmpty) {
        country = match.first;
        callingCode = int.tryParse(country?.callingCode ?? '');
      }
    }
  }

  notify() {
    if (callingCode != null &&
        phoneNumber != null &&
        phoneNumber.toString().length > 1) {
      Int64 number = Int64.parseInt(phoneNumber.toString());
      PhoneNumber newNumber = PhoneNumber(
        countryCode: callingCode!,
        nationalNumber: number,
      );
      final formatted = phoneUtil.format(newNumber, PhoneNumberFormat.e164);
      widget.onChanged(formatted);
    } else if (callingCode != null || phoneNumber != null) {
      if (mounted) setState(() {});
    } else {
      widget.onChanged(null);
    }
  }

  @override
  void initState() {
    callingCode = null;
    country = null;
    phoneNumber = null;
    if (widget.value != null) {
      formatInput(widget.value!);
    }
    getCountryData();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant PhoneInput oldWidget) {
    if (widget.value != null) {
      formatInput(widget.value!);
    }
    getCountryData();
    setState(() {});
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    List<ISOCountry> items = ISOCountries.countries
        .where((element) => element.callingCode != null)
        .toList();
    final locales = AppLocalizations.of(context);
    final inputValidation = InputValidation(locales: locales);
    List<ButtonOptions> options = List.generate(items.length, (index) {
      final item = items[index];
      return ButtonOptions(
        label: '(+${item.callingCode}) ${item.name}',
        labelAlt: item.fullName,
        value: int.tryParse(item.callingCode!),
      );
    });
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 200,
          ),
          child: InputData(
            autofillHints: const [],
            prefixIcon: const Icon(Icons.flag),
            label: locales.get('label--country'),
            hintText: locales.get('label--choose-label',
                {'label': locales.get('label--country')}),
            value: callingCode,
            type: InputDataType.dropdown,
            options: options,
            onChanged: (dynamic value) {
              callingCode = value as int?;
              country = items.firstWhere(
                  (element) => element.callingCode == callingCode.toString());
              notify();
            },
            disabled: widget.disabled,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InputData(
            autofillHints: const [],
            label: locales.get('label--phone-number'),
            hintText: '(234) 123-4567',
            value: phoneNumber,
            type: InputDataType.string,
            onChanged: (dynamic value) {
              if (value == null || value == '') {
                phoneNumber = null;
              } else {
                if ((value as String).startsWith('+')) {
                  formatInput(widget.value!);
                } else {
                  phoneNumber = int.tryParse(value);
                }
              }
              notify();
            },
            disabled: widget.disabled,
            validator: inputValidation.validatePhone,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[\s()-+]')),
              FilteringTextInputFormatter.allow(RegExp(r'[\d{0,15}]')),
              FilteringTextInputFormatter.singleLineFormatter,
            ],
          ),
        ),
      ],
    );
  }
}
