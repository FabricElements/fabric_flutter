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
    required this.value,
    this.onSubmit,
    this.onComplete,
    this.onChanged,
    this.disabled = false,
    this.country,
    this.suffix,
    this.suffixIcon,
    this.suffixText,
    this.prefixText,
    this.prefix,
    this.prefixIcon,
    this.prefixStyle,
    this.suffixStyle,
    this.label,
    this.textInputAction,
  });

  /// [onSubmit]
  /// Never use expression body or value won't be update correctly
  final ValueChanged<String?>? onSubmit;

  /// [onComplete]
  /// Never use expression body or value won't be update correctly
  final ValueChanged<String?>? onComplete;

  /// [onChanged]
  /// Never use expression body or value won't be update correctly
  final ValueChanged<String?>? onChanged;
  final String? label;
  final TextInputAction? textInputAction;

  // Custom suffix and prefix
  final Widget? suffix;
  final Widget? suffixIcon;
  final String? suffixText;
  final String? prefixText;
  final Widget? prefix;
  final Widget? prefixIcon;
  final TextStyle? prefixStyle;
  final TextStyle? suffixStyle;

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
  late List<ISOCountry> items;

  String? formattedNumber;
  bool isValid = false;

  /// Format the input string to extract the country code and phone number
  formatInput(String input) {
    try {
      PhoneNumber parsedNumber = phoneUtil.parseAndKeepRawInput(
          input, widget.country?.toUpperCase() ?? 'US');
      isValid = phoneUtil.isValidNumber(parsedNumber);
      callingCode = parsedNumber.countryCode;
      phoneNumber = parsedNumber.nationalNumber.toInt();
      country = items.firstWhere(
          (element) => element.callingCode == callingCode.toString());
      if (isValid) {
        formattedNumber =
            phoneUtil.format(parsedNumber, PhoneNumberFormat.e164);
      } else if (callingCode != null && phoneNumber != null) {
        formattedNumber = '+$callingCode$phoneNumber';
      }
    } on NumberParseException catch (e) {
      debugPrint('NumberParseException was thrown: ${e.toString()}');
      // formattedNumber = null;
      isValid = false;
      switch (e.errorType) {
        case ErrorType.invalidCountryCode:
          callingCode = null;
          break;
        case ErrorType.notANumber:
          // callingCode = null;
          // phoneNumber = null;
          // formattedNumber = null;
          break;
        case ErrorType.tooShortNsn:
        case ErrorType.tooLong:
        case ErrorType.tooShortAfterIdd:
          // Do nothing
          break;
        default:
          debugPrint('Unknown error: ${e.toString()}');
          // callingCode = null;
          // phoneNumber = null;
          formattedNumber = null;
      }
    }
    if (mounted) setState(() {});
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

  formatNumber() {
    isValid = false;
    try {
      if (callingCode != null && phoneNumber != null) {
        if (phoneNumber.toString().length > 6) {
          try {
            Int64 number = Int64.parseInt(phoneNumber.toString());
            PhoneNumber newNumber = PhoneNumber(
              countryCode: callingCode!,
              nationalNumber: number,
            );
            formattedNumber =
                phoneUtil.format(newNumber, PhoneNumberFormat.e164);
            isValid = phoneUtil.isValidNumber(newNumber);
          } catch (e) {
            debugPrint('Error formatting number: $e');
            formattedNumber = '+$callingCode$phoneNumber';
          }
        } else {
          formattedNumber = '+$callingCode$phoneNumber';
        }
      } else {
        formattedNumber = null;
      }
    } catch (e) {
      debugPrint('Error formatting number: $e');
      formattedNumber = null;
    }
  }

  _reset() {
    callingCode = null;
    country = null;
    phoneNumber = null;
    formattedNumber = null;
    isValid = false;
  }

  @override
  void initState() {
    final baseCountries = ISOCountries.countries
        .where((element) => element.callingCode != null)
        .toList();
    items = [];
    for (var element in baseCountries) {
      // Add the country to the list but merge if already exist same calling code
      if (!items.any((item) => item.callingCode == element.callingCode)) {
        items.add(element);
      } else {
        final index =
            items.indexWhere((item) => item.callingCode == element.callingCode);
        items[index].name = '${items[index].name}, ${element.name}';
        items[index].alpha2 = '${items[index].alpha2}, ${element.alpha2}';
        items[index].fullName = '${items[index].fullName}, ${element.fullName}';
      }
    }
    _reset();
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
    } else {
      phoneNumber = null;
      formattedNumber = null;
      isValid = false;
    }
    getCountryData();
    setState(() {});
    super.didUpdateWidget(oldWidget);
  }

  @override
  dispose() {
    phoneNumber = null;
    formattedNumber = null;
    isValid = false;
    country = null;
    callingCode = null;
    super.dispose();
  }

  _updatePhoneNumber(dynamic value) {
    if (value == null || value == '') {
      phoneNumber = null;
    } else {
      if ((value as String).startsWith('+')) {
        formatInput(widget.value!);
      } else {
        phoneNumber = int.tryParse(value);
      }
    }
    formatNumber();
  }

  @override
  Widget build(BuildContext context) {
    final isValidMatch =
        isValid || InputValidation.isPhoneValid(formattedNumber);
    final locales = AppLocalizations.of(context);
    final inputValidation = InputValidation(locales: locales);
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final small = width < 400;
      List<ButtonOptions> options = List.generate(items.length, (index) {
        final item = items[index];
        return ButtonOptions(
          label: '${item.name} (+${item.callingCode})',
          labelAlt: '${item.fullName} ${item.alpha2}',
          value: int.tryParse(item.callingCode!),
        );
      });
      final countryPicker = InputData(
        autofillHints: const [],
        prefixIcon: widget.prefixIcon ?? const Icon(Icons.phone_iphone),
        label: locales.get('label--country-code'),
        hintText: locales.get(
            'label--choose-label', {'label': locales.get('label--country')}),
        value: callingCode,
        type: InputDataType.dropdown,
        options: options,
        onChanged: (dynamic value) {
          callingCode = value as int?;
          country = items.firstWhere(
              (element) => element.callingCode == callingCode.toString());
          formatNumber();
          if (mounted) setState(() {});
          widget.onChanged?.call(formattedNumber);
          widget.onComplete?.call(formattedNumber);
          widget.onSubmit?.call(formattedNumber);
        },
        disabled: widget.disabled,
      );
      final phoneInput = InputData(
        disabled: widget.disabled || callingCode == null,
        // prefix: widget.prefix,
        prefix: country != null
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('+${country!.callingCode}'),
              )
            : null,
        // prefixIcon: widget.prefixIcon ?? const Icon(Icons.phone_iphone),
        prefixText: widget.prefixText,
        suffix: !isValidMatch ? null : widget.suffix,
        suffixText: !isValidMatch ? null : widget.suffixText,
        suffixIcon: !isValidMatch ? null : widget.suffixIcon,
        prefixStyle: widget.prefixStyle,
        suffixStyle: widget.suffixStyle,
        autofillHints: const [],
        label: widget.label ?? locales.get('label--phone-number'),
        hintText: '(234) 123-4567',
        value: phoneNumber,
        type: InputDataType.string,
        onChanged: (dynamic value) {
          _updatePhoneNumber(value);
          if (mounted) setState(() {});
          widget.onChanged?.call(formattedNumber);
        },
        onComplete: (dynamic value) {
          _updatePhoneNumber(value);
          if (isValidMatch) widget.onComplete?.call(formattedNumber);
        },
        onSubmit: (dynamic value) {
          _updatePhoneNumber(value);
          if (isValidMatch) widget.onSubmit?.call(formattedNumber);
        },
        validator: inputValidation.validatePhone,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'[\s()-+]')),
          FilteringTextInputFormatter.allow(RegExp(r'[\d{0,15}]')),
          FilteringTextInputFormatter.singleLineFormatter,
        ],
        maxLength: 10,
      );
      if (small) {
        return Column(
          children: [
            countryPicker,
            const SizedBox(height: 16),
            phoneInput,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 210,
            ),
            child: countryPicker,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: phoneInput,
          ),
        ],
      );
    });
  }
}
