import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/enum_data.dart';
import '../helper/input_validation.dart';
import '../helper/log_color.dart';
import '../helper/options.dart';
import '../helper/utils.dart';
import 'smart_image.dart';

/// InputDataType defines the supported types for the [InputData] component
enum InputDataType {
  date,
  time,
  dateTime,
  timestamp,
  email,
  int,
  double,
  currency,
  percent,
  text,
  enums,
  dropdown,
  string,
  radio,
  phone,
  secret,
  url,
  bool,
}

/// Input Data Type default icon
IconData inputDataTypeIcon(InputDataType inputDataType) {
  late IconData icon;
  switch (inputDataType) {
    case InputDataType.date:
      icon = Icons.calendar_month;
      break;
    case InputDataType.dateTime:
      icon = Icons.date_range;
      break;
    case InputDataType.timestamp:
      icon = Icons.access_time;
      break;
    case InputDataType.time:
      icon = Icons.access_time;
      break;
    case InputDataType.email:
      icon = Icons.email;
      break;
    case InputDataType.int:
      icon = Icons.pin;
      break;
    case InputDataType.double:
      icon = Icons.numbers;
      break;
    case InputDataType.currency:
      icon = Icons.attach_money;
      break;
    case InputDataType.percent:
      icon = Icons.percent;
      break;
    case InputDataType.text:
      icon = Icons.short_text;
      break;
    case InputDataType.enums:
      icon = Icons.list;
      break;
    case InputDataType.dropdown:
      icon = Icons.list;
      break;
    case InputDataType.string:
      icon = Icons.text_fields;
      break;
    case InputDataType.radio:
      icon = Icons.radio_button_checked;
      break;
    case InputDataType.phone:
      icon = Icons.phone;
      break;
    case InputDataType.secret:
      icon = Icons.security;
      break;
    case InputDataType.url:
      icon = Icons.link;
      break;
    case InputDataType.bool:
      icon = Icons.toggle_off_outlined;
      break;
  }
  return icon;
}

/// Parse value by input data type
/// This function is used to parse the value to the correct type
dynamic parseValueByInputDataType({
  required InputDataType type,
  required dynamic value,
  enums = const [],
}) {
  if (value == null) return null;
  dynamic baseValueAsString = value?.toString();
  if (baseValueAsString.isEmpty) return null;
  dynamic newValue;
  // Use [baseValue] to parse the value with the correct type similar to [InputData.getValue]
  switch (type) {
    case InputDataType.double:
    case InputDataType.currency:
    case InputDataType.percent:
      if (baseValueAsString.endsWith('.')) {
        baseValueAsString = baseValueAsString.replaceAll('.', '');
      }
      newValue = double.tryParse(baseValueAsString);
      break;
    case InputDataType.int:
      newValue = int.tryParse(baseValueAsString);
      break;
    case InputDataType.phone:
      // only accept digits
      String onlyNumbers = baseValueAsString
          .replaceAll(RegExp(r'\D'), '')
          .replaceAll(RegExp(r'\+'), '');
      // Add plus sign at the beginning if it's missing
      newValue = onlyNumbers.isEmpty ? null : '+$onlyNumbers';
      break;
    // add missing cases
    case InputDataType.date:
    case InputDataType.dateTime:
    case InputDataType.timestamp:
      newValue = DateTime.tryParse(baseValueAsString);
      break;
    case InputDataType.time:
      final timeBase = DateTime.tryParse(baseValueAsString);
      newValue = timeBase != null ? TimeOfDay.fromDateTime(timeBase) : null;
      break;
    case InputDataType.enums:
      newValue = EnumData.find(
        enums: enums,
        value: value,
      );
      break;
    case InputDataType.dropdown:
      newValue = value;
      break;
    case InputDataType.bool:
      if (value is bool) {
        newValue = value;
      } else {
        newValue = bool.tryParse(baseValueAsString);
      }
      break;
    case InputDataType.text:
    case InputDataType.email:
    case InputDataType.secret:
    case InputDataType.url:
    case InputDataType.string:
      newValue = baseValueAsString;
      break;
    case InputDataType.radio:
      newValue = value;
  }

  return newValue;
}

/// InputData provides an useful way to handle data input
/// It's much faster to use this component because includes all the controllers
/// you require for multiple data types [InputDataType]
class InputData extends StatefulWidget {
  const InputData({
    super.key,
    required this.value,
    required this.type,
    this.enums = const [],
    this.options = const [],
    this.onChanged,
    this.onSubmit,
    this.onComplete,
    this.disabled = false,
    this.hintText,
    this.isDense = false,
    this.maxLength,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.margin = EdgeInsets.zero,
    this.utcOffset,
    this.validator,
    this.backgroundColor,
    this.error,
    this.textStyle,
    this.obscureText = false,
    this.label,
    this.textInputAction,
    this.autocorrect = false,
    this.autofocus = false,
    this.textController,
    this.autofillHints,
    this.suffix,
    this.suffixText,
    this.suffixIcon,
    this.suffixStyle,
    this.prefix,
    this.prefixText,
    this.prefixIcon,
    this.prefixStyle,
    this.floatingLabelBehavior,
    this.searchController,
    this.asLocalTime = false,
    this.enableInteractiveSelection,
    this.inputFormatters = const [],
    this.keyboardType,
  });

  final dynamic value;
  final List<dynamic> enums;
  final List<ButtonOptions> options;
  final InputDataType type;
  final bool disabled;
  final String? hintText;
  final int? maxLength;
  final bool isDense;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final int? utcOffset;
  final FormFieldValidator<String>? validator;
  final Color? backgroundColor;
  final String? error;
  final TextStyle? textStyle;
  final bool obscureText;
  final String? label;
  final TextInputAction? textInputAction;
  final bool autocorrect;
  final bool autofocus;
  final TextEditingController? textController;
  final Iterable<String>? autofillHints;

  // Custom suffix and prefix
  final Widget? suffix;
  final Widget? suffixIcon;
  final String? suffixText;
  final String? prefixText;
  final Widget? prefix;
  final Widget? prefixIcon;
  final TextStyle? prefixStyle;
  final TextStyle? suffixStyle;

  /// [onSubmit]
  /// Never use expression body or value won't be update correctly
  final ValueChanged<dynamic>? onSubmit;

  /// [onComplete]
  /// Never use expression body or value won't be update correctly
  final ValueChanged<dynamic>? onComplete;

  /// [onChanged]
  /// Never use expression body or value won't be update correctly
  final ValueChanged<dynamic>? onChanged;

  /// {@template flutter.material.inputDecoration.floatingLabelBehavior}
  /// Defines **how** the floating label should behave.
  ///
  /// When [FloatingLabelBehavior.auto] the label will float to the top only when
  /// the field is focused or has some text content, otherwise it will appear
  /// in the field in place of the content.
  ///
  /// When [FloatingLabelBehavior.always] the label will always float at the top
  /// of the field above the content.
  ///
  /// When [FloatingLabelBehavior.never] the label will always appear in an empty
  /// field in place of the content.
  /// {@endtemplate}
  ///
  /// If null, [InputDecorationTheme.floatingLabelBehavior] will be used.
  ///
  /// See also:
  ///
  ///  * [floatingLabelAlignment] which defines **where** the floating label
  ///    should be displayed.
  final FloatingLabelBehavior? floatingLabelBehavior;

  /// An optional controller that allows opening and closing of the search view from
  /// other widgets.
  ///
  /// If this is null, one internal search controller is created automatically
  /// and it is used to open the search view when the user taps on the anchor.
  final SearchController? searchController;

  /// Show local time
  /// If true, the time will be shown in the local time zone
  /// if false, the time will be shown in the UTC time zone
  final bool asLocalTime;

  final bool? enableInteractiveSelection;

  final List<TextInputFormatter> inputFormatters;

  /// {@macro flutter.widgets.editableText.keyboardType}
  final TextInputType? keyboardType;

  @override
  State<InputData> createState() => _InputDataState();
}

class _InputDataState extends State<InputData> {
  late TextEditingController textController;
  late SearchController searchController;
  DateFormat formatDate = DateFormat.yMd('en_US');
  DateFormat formatDateTime =
      DateFormat.yMd('en_US').addPattern(' - ').add_jm();
  String? prefixText;
  dynamic value;
  late bool obscureText;
  late bool obscure;

  /// Format New Value
  dynamic valueChanged(dynamic valueLocal) {
    if (valueLocal == null) return null;
    String valueLocalString = valueLocal!.toString();
    if (valueLocalString.isEmpty) return null;
    switch (widget.type) {
      case InputDataType.double:
      case InputDataType.currency:
      case InputDataType.percent:
        if (valueLocalString.endsWith('.')) {
          valueLocalString = valueLocalString.replaceAll('.', '');
        }
        return double.tryParse(valueLocalString);
      case InputDataType.int:
        return int.tryParse(valueLocalString);
      case InputDataType.phone:
        // only accept digits
        String onlyNumbers = valueLocalString
            .replaceAll(RegExp(r'\D'), '')
            .replaceAll(RegExp(r'\+'), '');
        // Add plus sign at the beginning
        return '+$onlyNumbers';
      default:
        return valueLocal;
    }
  }

  /// Get Value from parameter
  void getValue({bool notify = false, required dynamic newValue}) {
    try {
      switch (widget.type) {
        case InputDataType.currency:
        case InputDataType.percent:
        case InputDataType.double:
        case InputDataType.int:
        case InputDataType.string:
        case InputDataType.text:
        case InputDataType.email:
        case InputDataType.secret:
        case InputDataType.url:
          dynamic newFormattedValue = valueChanged(newValue)?.toString() ?? '';
          bool sameValue = value == newFormattedValue;
          if (!sameValue) {
            value = newFormattedValue;
            textController.text = value;
            if (notify && mounted) setState(() {});
          }
          break;
        case InputDataType.phone:
          dynamic newFormattedValue = valueChanged(newValue)?.toString() ?? '';
          // remove plus sign to avoid double plus sign on the input
          final valueWithoutPlusSign =
              newFormattedValue.replaceAll(RegExp(r'\+'), '');
          bool sameValue = value == newFormattedValue;
          if (!sameValue) {
            value = newFormattedValue;
            textController.text = valueWithoutPlusSign;
            if (notify && mounted) setState(() {});
          }
          break;
        case InputDataType.date:
        case InputDataType.dateTime:
        case InputDataType.timestamp:
          DateTime? baseValue = newValue != null ? newValue as DateTime : null;
          if (baseValue != null && widget.utcOffset != null) {
            baseValue = Utils.dateTimeOffset(
              dateTime: baseValue,
              utcOffset: widget.utcOffset,
            );
          }
          // Set the text
          baseValue =
              widget.asLocalTime ? baseValue?.toLocal() : baseValue?.toUtc();
          if (baseValue != null) {
            if (widget.type == InputDataType.date) {
              textController.text = formatDate.format(baseValue);
            } else {
              textController.text = formatDateTime.format(baseValue);
            }
          } else {
            textController.text = '';
          }
          // Set the value
          value = baseValue;

          if (notify && mounted) setState(() {});
          break;
        case InputDataType.time:
          value = newValue as TimeOfDay?;
          if (notify && mounted) setState(() {});
          break;
        case InputDataType.enums:
          value = EnumData.find(
            enums: widget.enums,
            value: newValue,
          );
          dynamic newFormattedValue = valueChanged(newValue)?.toString() ?? '';
          bool sameValue = value == newFormattedValue;
          if (!sameValue) {
            value = newFormattedValue;
            if (notify && mounted) setState(() {});
          }
          break;
        case InputDataType.dropdown:
          final optionMatch = widget.options.where((item) {
            return item.value == newValue;
          });
          bool valueInOptions = optionMatch.isNotEmpty;
          if (valueInOptions) {
            value = newValue;
          } else {
            value = null;
          }
          dynamic newFormattedValue = valueChanged(newValue)?.toString() ?? '';
          bool sameValue = value == newFormattedValue;
          if (!sameValue) {
            value = newFormattedValue;
            textController.text = valueInOptions ? optionMatch.first.label : '';
            if (notify && mounted) setState(() {});
          }
          break;
        case InputDataType.bool:
          bool baseValue = false;
          if (newValue == null) {
            baseValue = false;
          } else if (newValue.runtimeType == bool) {
            baseValue = newValue;
          } else {
            String valueAsString = newValue.toString().toLowerCase();
            if (valueAsString.isNotEmpty) {
              baseValue = valueAsString == 'true' || valueAsString == '1';
            }
          }
          value = baseValue;
          textController.text = '';
          if (notify && mounted) setState(() {});
          break;
        case InputDataType.radio:
          value = newValue;
          if (notify && mounted) setState(() {});
          break;
      }
    } catch (e) {
      debugPrint(LogColor.error('''
----------------------------------------------
getValue -------------------------------------
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
'''));
      rethrow;
    }
  }

  @override
  void initState() {
    /// Validate required parameters on init
    switch (widget.type) {
      case InputDataType.enums:
        assert(widget.enums.isNotEmpty,
            'enums is required for InputDataType.enums');
        break;
      case InputDataType.dropdown:
        if (widget.options.isEmpty) {
          debugPrint('options is required for InputDataType.dropdown');
        }
        break;
      default:
    }
    textController = widget.textController ?? TextEditingController();
    searchController = widget.searchController ?? SearchController();

    /// obscure text and show controls
    obscureText = widget.obscureText;
    if (widget.type == InputDataType.secret) obscureText = true;
    obscure = obscureText;

    /// Get value
    getValue(newValue: widget.value);
    super.initState();
  }

  /// Close search controller
  void _closeSearch() {
    try {
      searchController.clear();
      if (searchController.isOpen) searchController.closeView(null);
    } catch (e) {
      // Do nothing
    }
  }

  /// Clear the input
  void _clear() {
    widget.onChanged?.call(null);
    widget.onComplete?.call(null);
    widget.onSubmit?.call(null);
  }

  @override
  void didUpdateWidget(covariant InputData oldWidget) {
    getValue(notify: false, newValue: widget.value);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _closeSearch();
    try {
      textController.dispose();
      // Dispose the search controller if it's not attached to the widget
      if (widget.searchController == null && searchController.isAttached) {
        searchController.dispose();
      }
    } catch (e) {
      // Do nothing
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final enumData = EnumData(locales: locales);
    final theme = Theme.of(context);
    bool isDense = widget.isDense || theme.inputDecorationTheme.isDense;
    bool isDisabled = widget.disabled;
    String defaultTextOptions = locales.get('label--choose-option');
    String? hintTextDefault;
    int? maxLength = widget.maxLength;
    FormFieldValidator<String>? validator = widget.validator;
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;
    final clearWidget = isDisabled
        ? null
        : IconButton(
            onPressed: _clear,
            icon: const Icon(Icons.clear),
            tooltip: locales.get('label--clear'),
          );

    /// Text styles
    String? errorText;
    if (widget.error != null) {
      errorText = widget.error;
    }

    Widget? inputSuffixIcon;
    if (obscure) {
      inputSuffixIcon = IconButton(
        onPressed: () {
          obscureText = !obscureText;
          if (mounted) setState(() {});
        },
        icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
      );
    }

    /// Add clear button when is not possible to set value to null
    switch (widget.type) {
      case InputDataType.date:
      case InputDataType.dateTime:
      case InputDataType.timestamp:
      case InputDataType.time:
        if (value != null) {
          inputSuffixIcon = clearWidget;
        }
        break;
      case InputDataType.phone:
        inputSuffixIcon = Tooltip(
          message: locales.get('label--info-phone-number-format'),
          child: Icon(Icons.info),
        );
      default:
        break;
    }

    Widget endWidget = Text(
      'Type "${widget.type}" not implemented',
      style: const TextStyle(color: Colors.orange),
    );
    TextInputType keyboardType = TextInputType.text;
    TextInputAction? textInputAction = widget.textInputAction;
    List<TextInputFormatter> inputFormatters = [...widget.inputFormatters];
    final inputValidation = InputValidation(locales: locales);
    switch (widget.type) {
      case InputDataType.text:
        keyboardType = TextInputType.multiline;
        textInputAction = widget.textInputAction ?? TextInputAction.newline;
        break;
      case InputDataType.phone:
        // https://en.wikipedia.org/wiki/Telephone_numbering_plan
        maxLength = 16;
        prefixText = '+';
        hintTextDefault = '1 (222) 333 - 4444';
        keyboardType = TextInputType.phone;
        inputFormatters.addAll([
          FilteringTextInputFormatter.deny(RegExp(r'[\s()-+]')),
          FilteringTextInputFormatter.allow(RegExp(r'[\d{0,15}]')),
          FilteringTextInputFormatter.singleLineFormatter,
        ]);
        validator = inputValidation.validatePhone;
        break;
      case InputDataType.email:
        maxLength = 100;
        hintTextDefault = 'example@example.com';
        keyboardType = TextInputType.emailAddress;
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
        ]);
        validator = inputValidation.validateEmail;
        break;
      case InputDataType.url:
        hintTextDefault = 'https://example.com';
        keyboardType = TextInputType.url;
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
        ]);
        validator = inputValidation.validateUrl;
        break;
      case InputDataType.double:
      case InputDataType.currency:
      case InputDataType.percent:
        keyboardType =
            const TextInputType.numberWithOptions(decimal: true, signed: true);
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
          FilteringTextInputFormatter.allow(RegExp(r'[\d.-]')),
        ]);
        break;
      case InputDataType.int:
        keyboardType = const TextInputType.numberWithOptions(signed: true);
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
          FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
        ]);
        break;
      case InputDataType.date:
      case InputDataType.dateTime:
      case InputDataType.timestamp:
        keyboardType = TextInputType.datetime;
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
        ]);
        hintTextDefault = locales.get('label--choose-label', {
          'label': locales.get('label--date'),
        });
        break;
      case InputDataType.secret:
        keyboardType = TextInputType.visiblePassword;
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
        ]);
        break;
      case InputDataType.enums:
      case InputDataType.dropdown:
        hintTextDefault = defaultTextOptions;
        break;
      default:
    }

    /// Override keyboard type using parameter
    if (widget.keyboardType != null) {
      keyboardType = widget.keyboardType!;
    }

    String? hintText = widget.hintText ?? hintTextDefault;
    if (!widget.obscureText) {
      hintText =
          (value?.toString() ?? '').isNotEmpty ? value?.toString() : hintText;
    }
    final inputDecoration = InputDecoration(
      hintText: hintText,
      isDense: isDense,
      errorText: errorText,
      errorMaxLines: 2,
      enabled: !widget.disabled,
      prefix: widget.prefix,
      suffix: widget.suffix,
      prefixIcon: widget.prefixIcon,
      suffixIcon: widget.suffixIcon ?? inputSuffixIcon,
      prefixText: widget.prefixText ?? prefixText,
      suffixText: widget.suffixText,
      prefixStyle: widget.prefixStyle,
      suffixStyle: widget.suffixStyle,
      labelText: widget.label,
      labelStyle: theme.textTheme.bodyMedium,
      floatingLabelBehavior: widget.floatingLabelBehavior,
      contentPadding: isDense
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 4)
          : widget.padding,
    );

    switch (widget.type) {
      case InputDataType.int:
      case InputDataType.double:
      case InputDataType.currency:
      case InputDataType.percent:
      case InputDataType.string:
      case InputDataType.text:
      case InputDataType.phone:
      case InputDataType.email:
      case InputDataType.secret:
      case InputDataType.url:
        endWidget = TextFormField(
          controller: textController,
          autofillHints: widget.autofillHints,
          autofocus: widget.autofocus,
          autocorrect: widget.autocorrect,
          enableSuggestions: false,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          maxLines: widget.type == InputDataType.text ? 10 : 1,
          minLines: 1,
          maxLength: maxLength,
          decoration: inputDecoration,
          obscureText: obscureText,
          enableInteractiveSelection: widget.enableInteractiveSelection,
          onChanged: (newValue) {
            dynamic newFormattedValue = valueChanged(newValue);
            bool sameValue = value == newFormattedValue;
            if (!sameValue) {
              value = newFormattedValue?.toString() ?? '';
              widget.onChanged?.call(newFormattedValue);
            }
          },
          onFieldSubmitted: widget.onSubmit == null
              ? null
              : (newValue) {
                  widget.onSubmit!(valueChanged(value));
                  FocusManager.instance.primaryFocus?.unfocus();
                },
          onEditingComplete: widget.onComplete == null
              ? null
              : () {
                  widget.onComplete!(valueChanged(value));
                  FocusManager.instance.primaryFocus?.unfocus();
                },
        );
        break;
      case InputDataType.date:
      case InputDataType.dateTime:
      case InputDataType.timestamp:
        endWidget = TextFormField(
          obscureText: obscureText,
          autofillHints: widget.autofillHints,
          enableSuggestions: false,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          controller: textController,
          readOnly: true,
          decoration: inputDecoration.copyWith(
            prefixIcon: inputDecoration.prefixIcon ??
                inputDecoration.prefixIcon ??
                Icon(inputDataTypeIcon(widget.type)),
          ),
          onTap: () async {
            // Apply format depending on [showAsLocalTime]
            DateTime now =
                widget.asLocalTime ? DateTime.now() : DateTime.timestamp();
            DateTime date = value ?? now;
            date = widget.asLocalTime ? date.toLocal() : date.toUtc();
            // If the date is in the future, use the current date
            DateTime dateBefore = now;
            DateTime dateAfter = now;
            if (value != null) {
              dateBefore = date.isBefore(now) ? date : now;
              dateAfter = date.isAfter(now) ? date : now;
            }
            late DateTime? picked;
            final minDate =
                dateBefore.subtract(const Duration(days: 365 * 101));
            final maxDate = dateAfter.add(const Duration(days: 365 * 101));
            if (widget.type == InputDataType.date) {
              picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: minDate,
                lastDate: maxDate,
              );
            } else if (widget.type == InputDataType.dateTime ||
                widget.type == InputDataType.timestamp) {
              picked = await showOmniDateTimePicker(
                context: context,
                initialDate: date,
                constraints: const BoxConstraints(
                  maxHeight: 800,
                  minHeight: 500,
                  minWidth: 400,
                  maxWidth: 800,
                ),
              );
            }
            if (picked != null) {
              DateTime newDate = picked;
              // Apply local time or utc time
              if (widget.asLocalTime) {
                newDate = newDate.toLocal();
              } else {
                // add Z to the end of the date to indicate it's UTC
                // if it's not already UTC
                if (!newDate.isUtc) {
                  newDate = DateTime.parse('${newDate.toIso8601String()}Z');
                }
                newDate = newDate.toUtc();
              }
              if (widget.utcOffset != null && widget.utcOffset != 0) {
                newDate = Utils.dateTimeOffset(
                  dateTime: newDate,
                  utcOffset: widget.utcOffset,
                  reverse: true,
                )!;
              }
              widget.onChanged?.call(newDate);
              widget.onComplete?.call(newDate);
              widget.onSubmit?.call(newDate);
            }
          },
        );
        break;
      case InputDataType.time:
        TimeOfDay? time = value;
        DateFormat formatTime = DateFormat.jm();
        String? dateString = time != null
            ? formatTime.format(DateTime(1, 1, 1, time.hour, time.minute))
            : null;
        String label = dateString ??
            locales.get('label--choose-label', {
              'label': locales.get('label--time'),
            });
        endWidget = FilledButton.icon(
          onPressed: isDisabled
              ? null
              : () async {
                  time ??= TimeOfDay.now();
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: time!,
                  );
                  if (picked != null && picked != time) {
                    widget.onChanged?.call(picked);
                    widget.onComplete?.call(picked);
                    widget.onSubmit?.call(picked);
                  }
                },
          icon: const Icon(Icons.access_time),
          label: Text(label),
        );
        break;
      case InputDataType.enums:
      case InputDataType.dropdown:
        List<ButtonOptions> dropdownOptions = [];
        if (widget.type == InputDataType.dropdown) {
          dropdownOptions = widget.options;
          final match = dropdownOptions.where((element) {
            return element.value == value;
          });
          if (value != null && match.isNotEmpty) {
            textController.text = match.first.label;
          }
        }
        if (widget.type == InputDataType.enums) {
          if (value != null && value != '') {
            textController.text = enumData.localesFromEnum(value);
          }
          dropdownOptions = List.generate(widget.enums.length, (index) {
            final e = widget.enums[index];
            return ButtonOptions(
              id: e.toString(),
              label: enumData.localesFromEnum(e),
              value: e,
            );
          });
        }
        final widgetInput = TextFormField(
          autofillHints: widget.autofillHints,
          enableSuggestions: false,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          controller: textController,
          readOnly: true,
          decoration: inputDecoration.copyWith(
            prefixIcon: inputDecoration.prefixIcon ??
                inputDecoration.prefixIcon ??
                Icon(inputDataTypeIcon(widget.type)),
            suffixIcon:
                inputDecoration.suffixIcon ?? const Icon(Icons.arrow_drop_down),
          ),
          onTap: isDisabled
              ? null
              : () async {
                  searchController.openView();
                },
        );
        if (!isDisabled) {
          endWidget = SearchAnchor(
            viewHintText: locales.get('label--search'),
            isFullScreen: isSmallScreen,
            viewLeading: BackButton(
              onPressed: _closeSearch,
            ),
            viewTrailing: [
              if (value != null && value.toString().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () {
                    _closeSearch();
                    _clear();
                  },
                  icon: const Icon(Icons.clear),
                  label: Text(locales.get('label--clear')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    iconColor: theme.colorScheme.error,
                    side: BorderSide(
                        color:
                            theme.buttonTheme.colorScheme?.error ?? Colors.red),
                  ),
                ),
            ],
            searchController: searchController,
            builder: (BuildContext context, SearchController controller) {
              return PointerInterceptor(child: widgetInput);
            },
            suggestionsBuilder:
                (BuildContext context, SearchController controller) {
              final value = controller.text;
              List<ButtonOptions> recommendations = dropdownOptions;
              if (value.isNotEmpty) {
                recommendations = recommendations.where((element) {
                  final labelMatch =
                      element.label.toLowerCase().contains(value.toLowerCase());
                  final labelAltMatch = element.labelAlt
                          ?.toLowerCase()
                          .contains(value.toLowerCase()) ??
                      false;
                  final valueMatch = element.value.toString().contains(value);
                  return labelMatch || valueMatch || labelAltMatch;
                }).toList();
              }
              return List.generate(recommendations.length, (int index) {
                final item = recommendations[index];

                /// Leading
                Widget? leading = item.leading;
                if (item.icon != null) {
                  leading = Icon(item.icon);
                }
                if (item.image != null) {
                  leading = Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      child: AspectRatio(
                        aspectRatio: 1 / 1,
                        child: ClipOval(
                          child: SmartImage(
                            url: item.image,
                            format: AvailableOutputFormats.png,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                /// Trailing
                Widget? trailing = item.trailing;
                if (item.trailingIcon != null) {
                  trailing = Icon(item.trailingIcon);
                }
                if (item.trailingImage != null) {
                  trailing = AspectRatio(
                    aspectRatio: 1 / 1,
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(item.trailingImage!),
                    ),
                  );
                }
                return PointerInterceptor(
                  child: ListTile(
                    leading: leading,
                    trailing: trailing,
                    title: Text(item.label),
                    onTap: () {
                      dynamic newValue = item.value == '' ? null : item.value;
                      _closeSearch();
                      widget.onChanged?.call(newValue);
                      widget.onComplete?.call(newValue);
                      widget.onSubmit?.call(newValue);
                    },
                  ),
                );
              });
            },
          );
        } else {
          endWidget = widgetInput;
        }
        break;
      case InputDataType.radio:
        List<Widget> radioOptions =
            List.generate(widget.options.length, (index) {
          final e = widget.options[index];
          return RadioListTile(
            title: Text(e.label),
            toggleable: !isDisabled,
            value: e.value,
            groupValue: value,
            selected: value == e.value,
            onChanged: (newValue) {
              value = newValue;
              widget.onChanged?.call(value);
              widget.onComplete?.call(value);
              widget.onSubmit?.call(value);
            },
          );
        });
        endWidget = Flex(
          direction: Axis.vertical,
          mainAxisSize: MainAxisSize.min,
          children: radioOptions,
        );
        break;
      case InputDataType.bool:
        endWidget = TextFormField(
          controller: textController,
          initialValue: null,
          mouseCursor: MouseCursor.uncontrolled,
          autofillHints: widget.autofillHints,
          readOnly: true,
          decoration: inputDecoration.copyWith(
            floatingLabelBehavior:
                widget.floatingLabelBehavior ?? FloatingLabelBehavior.never,
            labelText: null,
            prefixIcon: inputDecoration.prefixIcon ??
                Icon(inputDataTypeIcon(widget.type)),
            suffixIcon: Switch(
              value: value,
              onChanged: (newValue) {
                widget.onChanged?.call(newValue);
                widget.onComplete?.call(newValue);
                widget.onSubmit?.call(newValue);
              },
            ),
          ),
          onTap: () async {
            bool newValue = !value;
            widget.onChanged?.call(newValue);
            widget.onComplete?.call(newValue);
            widget.onSubmit?.call(newValue);
          },
        );
        break;
    }
    return Container(
      margin: widget.margin,
      child: endWidget,
    );
  }
}
