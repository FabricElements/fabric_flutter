import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/input_validation.dart';
import '../helper/iso_countries.dart';
import '../helper/options.dart';
import '../serialized/iso_data.dart';
import 'input_data.dart';

/// Collects a phone number by separating country selection from the national
/// number entry field.
///
/// The widget keeps derived formatting state in sync with the Flutter lifecycle
/// so parents can receive normalized values through the change, completion, and
/// submit callbacks without reimplementing phone parsing rules.
class PhoneInput extends StatefulWidget {
  /// Creates a phone input that formats and validates values with
  /// [PhoneNumberUtil].
  ///
  /// The widget parses [value] into a country picker selection and a national
  /// number field so callers can provide or receive normalized E.164-style
  /// strings without managing phone metadata themselves.
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

  /// Provides the latest formatted value when the user submits the number.
  ///
  /// Parents receive a normalized [String] or `null` after the widget refreshes
  /// its derived state.
  final ValueChanged<String?>? onSubmit;

  /// Provides the latest formatted value when entry is considered complete.
  ///
  /// Parents receive a normalized [String] or `null` after the widget refreshes
  /// its derived state.
  final ValueChanged<String?>? onComplete;

  /// Provides the latest formatted value when either input changes.
  ///
  /// Parents receive a normalized [String] or `null` whenever the selected
  /// calling code or national number changes.
  final ValueChanged<String?>? onChanged;

  /// Overrides the localized label for the national number field.
  final String? label;

  /// Defines the keyboard action button for the number input when supported.
  final TextInputAction? textInputAction;

  /// Displays a custom trailing widget when the number is currently valid.
  final Widget? suffix;

  /// Displays a custom trailing icon when the number is currently valid.
  final Widget? suffixIcon;

  /// Displays trailing helper text when the number is currently valid.
  final String? suffixText;

  /// Displays additional prefix text before the national number field.
  final String? prefixText;

  /// Reserves a custom leading widget slot for the number field.
  final Widget? prefix;

  /// Overrides the icon shown on the country selector input.
  final Widget? prefixIcon;

  /// Overrides the text style used by [prefixText].
  final TextStyle? prefixStyle;

  /// Overrides the text style used by [suffixText].
  final TextStyle? suffixStyle;

  /// Supplies the full phone number value that should be parsed into the UI.
  final String? value;

  /// Prevents interaction with both inputs when `true`.
  final bool disabled;

  /// Provides a preferred ISO country code used for parsing and defaults.
  final String? country;

  /// Creates state that caches parsed phone metadata between rebuilds.
  ///
  /// The returned [_PhoneInputState] keeps the country picker and national
  /// number field synchronized with [value].
  @override
  State<PhoneInput> createState() => _PhoneInputState();
}

/// Maintains parsed country and number fragments for [PhoneInput].
///
/// The state object caches country metadata and best-effort formatted output so
/// the widget can react to partial edits without losing the user's draft.
class _PhoneInputState extends State<PhoneInput> {
  /// Provides parsing and formatting utilities from the phone number package.
  final PhoneNumberUtil phoneUtil = PhoneNumberUtil.instance;

  /// Stores the selected international calling code.
  int? callingCode;

  /// Stores the selected country metadata shown in the picker and prefix.
  ISOCountry? country;

  /// Stores the national number portion entered by the user.
  int? phoneNumber;

  /// Stores the deduplicated list of selectable countries for mobile numbers.
  late List<ISOCountry> items;

  /// Stores the normalized output value forwarded to parent callbacks.
  String? formattedNumber;

  /// Indicates whether the current number satisfies library validation rules.
  bool isValid = false;

  /// Parses an incoming full phone number into the widget's internal fields.
  ///
  /// This runs for external value updates as well as initialization so the UI
  /// stays synchronized with parent state, even when partially valid values are
  /// supplied.
  void formatInput(String input) {
    try {
      PhoneNumber parsedNumber = phoneUtil.parseAndKeepRawInput(
        input,
        widget.country?.toUpperCase() ?? 'US',
      );
      isValid = phoneUtil.isValidNumber(parsedNumber);
      callingCode = parsedNumber.countryCode;
      phoneNumber = parsedNumber.nationalNumber.toInt();
      country = items.firstWhere(
        (element) => element.callingCode == callingCode.toString(),
      );
      if (isValid) {
        formattedNumber = phoneUtil.format(
          parsedNumber,
          PhoneNumberFormat.e164,
        );
      } else if (callingCode != null && phoneNumber != null) {
        formattedNumber = '+$callingCode$phoneNumber';
      }
    } on NumberParseException catch (e) {
      debugPrint('NumberParseException was thrown: ${e.toString()}');
      isValid = false;
      switch (e.errorType) {
        case ErrorType.invalidCountryCode:
          callingCode = null;
          break;
        case ErrorType.notANumber:
          break;
        case ErrorType.tooShortNsn:
        case ErrorType.tooLong:
        case ErrorType.tooShortAfterIdd:
          break;
        default:
          debugPrint('Unknown error: ${e.toString()}');
          formattedNumber = null;
      }
    }
    if (mounted) setState(() {});
  }

  /// Resolves the preferred country from [PhoneInput.country].
  ///
  /// The fallback applies only when parsing [PhoneInput.value] did not already
  /// determine a country from the incoming number.
  void getCountryData() {
    if (country == null && widget.country != null) {
      final match = ISOCountries.countries.where(
        (element) => element.alpha2 == widget.country!.toUpperCase(),
      );
      if (match.isNotEmpty) {
        country = match.first;
        callingCode = int.tryParse(country?.callingCode ?? '');
      }
    }
  }

  /// Rebuilds [formattedNumber] from the selected calling code and national
  /// number.
  ///
  /// Short or partially entered numbers intentionally keep a best-effort `+`
  /// representation so parent widgets can preserve drafts during editing.
  void formatNumber() {
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
            formattedNumber = phoneUtil.format(
              newNumber,
              PhoneNumberFormat.e164,
            );
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

  /// Clears all derived phone state before a fresh value is parsed.
  ///
  /// Resetting cached fields keeps stale parsing results from leaking across
  /// initialization and subsequent parent-driven updates.
  void _reset() {
    callingCode = null;
    country = null;
    phoneNumber = null;
    formattedNumber = null;
    isValid = false;
  }

  /// Builds the deduplicated country list and seeds the initial parsed value.
  ///
  /// Countries that share the same calling code are merged into a single picker
  /// option so the dropdown stays compact while still exposing all labels.
  @override
  void initState() {
    super.initState();
    final baseCountries = ISOCountries.countriesForMobile;
    items = [];

    for (var element in baseCountries) {
      if (!items.any((item) => item.callingCode == element.callingCode)) {
        items.add(element);
      } else {
        final index = items.indexWhere(
          (item) => item.callingCode == element.callingCode,
        );
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
  }

  /// Re-parses the external value whenever the parent rebuilds with new input.
  ///
  /// Clearing the cached phone fragments when [PhoneInput.value] becomes `null`
  /// keeps the rendered controls aligned with parent state.
  @override
  void didUpdateWidget(covariant PhoneInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null) {
      formatInput(widget.value!);
    } else {
      phoneNumber = null;
      formattedNumber = null;
      isValid = false;
    }
    getCountryData();
    setState(() {});
  }

  /// Clears cached parsing state before the widget is removed from the tree.
  ///
  /// Resetting the fields releases references to parsed values before calling
  /// [super.dispose].
  @override
  void dispose() {
    phoneNumber = null;
    formattedNumber = null;
    isValid = false;
    country = null;
    callingCode = null;
    super.dispose();
  }

  /// Updates the national number fragment and refreshes the formatted output.
  ///
  /// The method accepts the dynamic payload shape emitted by [InputData] and
  /// narrows it to the cached [int] representation used by this state object.
  void _updatePhoneNumber(dynamic value) {
    phoneNumber = value as int?;
    formatNumber();
  }

  /// Builds coordinated country and phone number inputs for [BuildContext].
  ///
  /// The layout switches between stacked and horizontal arrangements so the
  /// picker and number field remain usable across narrow and wide widths.
  @override
  Widget build(BuildContext context) {
    final isValidMatch =
        isValid || InputValidation.isPhoneValid(formattedNumber);
    final locales = AppLocalizations.of(context);
    final inputValidation = InputValidation(locales: locales);
    List<ButtonOptions> options = List.generate(items.length, (index) {
      final item = items[index];
      return ButtonOptions(
        label: '${item.name} (+${item.callingCode})',
        labelAlt: '${item.fullName} ${item.alpha2}',
        value: int.tryParse(item.callingCode!),
      );
    });
    final countryPicker = InputData(
      key: const Key('country-picker'),
      autofillHints: const [],
      prefixIcon: widget.prefixIcon ?? const Icon(Icons.phone_iphone),
      label: locales.get('label--country-code'),
      hintText: locales.get('label--choose-label', {
        'label': locales.get('label--country'),
      }),
      value: callingCode,
      type: InputDataType.dropdown,
      options: options,
      onChanged: (dynamic value) {
        callingCode = value as int?;
        country = items.firstWhere(
          (element) => element.callingCode == callingCode.toString(),
        );
        formatNumber();
        if (mounted) setState(() {});
        widget.onChanged?.call(formattedNumber);
        widget.onComplete?.call(formattedNumber);
        widget.onSubmit?.call(formattedNumber);
      },
      disabled: widget.disabled,
    );
    final phoneInput = InputData(
      key: const Key('phone-input'),
      disabled: widget.disabled || callingCode == null,
      prefix: country != null
          ? Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('+${country!.callingCode}'),
            )
          : null,
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
      type: InputDataType.int,
      keyboardType: TextInputType.number,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final small = width < 400;
        if (small) {
          return Column(
            children: [countryPicker, const SizedBox(height: 16), phoneInput],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 210),
              child: countryPicker,
            ),
            const SizedBox(width: 16),
            Expanded(child: phoneInput),
          ],
        );
      },
    );
  }
}
