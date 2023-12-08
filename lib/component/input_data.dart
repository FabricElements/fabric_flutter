import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/enum_data.dart';
import '../helper/input_validation.dart';
import '../helper/options.dart';
import '../helper/utils.dart';

/// InputDataType defines the supported types for the [InputData] component
enum InputDataType {
  date,
  time,
  dateTime,
  email,
  double,
  int,
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
    case InputDataType.time:
      icon = Icons.access_time;
      break;
    case InputDataType.email:
      icon = Icons.email;
      break;
    case InputDataType.double:
      icon = Icons.numbers;
      break;
    case InputDataType.int:
      icon = Icons.pin;
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
    this.isExpanded = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.margin = EdgeInsets.zero,
    this.utcOffset,
    this.validator,
    this.backgroundColor,
    // icon == prefixIcon
    this.icon,
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
  });

  final dynamic value;
  final List<dynamic> enums;
  final List<ButtonOptions> options;
  final InputDataType type;
  final bool disabled;
  final String? hintText;
  final int? maxLength;
  final bool isDense;
  final bool isExpanded;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final int? utcOffset;
  final FormFieldValidator<String>? validator;
  final Color? backgroundColor;
  final IconData? icon;
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

  @override
  State<InputData> createState() => _InputDataState();
}

class _InputDataState extends State<InputData> {
  late TextEditingController textController;
  SearchController searchController = SearchController();
  DateFormat formatDate = DateFormat.yMd('en_US');
  DateFormat formatDateTime =
      DateFormat.yMd('en_US').addPattern(' - ').add_jm();
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
        if (valueLocalString.endsWith('.')) {
          valueLocalString = valueLocalString.replaceAll('.', '');
        }
        return double.tryParse(valueLocalString);
      case InputDataType.int:
        return int.tryParse(valueLocalString);
      default:
        return valueLocal;
    }
  }

  /// Get Value from parameter
  void getValue({bool notify = false, required dynamic newValue}) {
    try {
      switch (widget.type) {
        case InputDataType.double:
        case InputDataType.string:
        case InputDataType.int:
        case InputDataType.text:
        case InputDataType.phone:
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
        case InputDataType.date:
        case InputDataType.dateTime:
          value = newValue != null ? newValue as DateTime : null;
          if (value != null && widget.utcOffset != null) {
            value = Utils.dateTimeOffset(
              dateTime: value,
              utcOffset: widget.utcOffset,
            );
          }
          if (value != null) {
            if (widget.type == InputDataType.date) {
              textController.text = formatDate.format(value);
            } else {
              textController.text = formatDateTime.format(value);
            }
          } else {
            textController.text = '';
          }
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
        default:
          value = newValue;
          if (notify && mounted) setState(() {});
      }
    } catch (e) {
      if (kDebugMode) {
        print('''
----------------------------------------------
getValue -------------------------------------
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
''');
      }
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
        assert(widget.options.isNotEmpty,
            'options is required for InputDataType.dropdown');
        break;
      default:
    }
    textController = widget.textController ?? TextEditingController();
    getValue(newValue: widget.value);

    /// obscure text and show controls
    obscureText = widget.obscureText;
    if (widget.type == InputDataType.secret) obscureText = true;
    obscure = obscureText;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant InputData oldWidget) {
    getValue(notify: true, newValue: widget.value);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context)!;
    final enumData = EnumData(locales: locales);
    final theme = Theme.of(context);
    bool isDense = widget.isDense || theme.inputDecorationTheme.isDense;
    bool isDisabled = widget.disabled;
    String defaultTextOptions = locales.get('label--choose-option');
    String? hintTextDefault;
    int? maxLength = widget.maxLength;
    FormFieldValidator<String>? validator = widget.validator;

    /// Text styles
    String? errorText;
    if (widget.error != null) {
      errorText = widget.error;
    }

    Widget? inputIcon;
    switch (widget.type) {
      case InputDataType.double:
      case InputDataType.int:
      case InputDataType.string:
      case InputDataType.text:
      case InputDataType.phone:
      case InputDataType.email:
      case InputDataType.secret:
      case InputDataType.url:
      case InputDataType.bool:
        inputIcon = widget.icon != null ? Icon(widget.icon) : null;
        break;
      default:
    }

    Widget? inputTrailingIcon;
    if (obscure) {
      inputTrailingIcon = IconButton(
        onPressed: () {
          obscureText = !obscureText;
          if (mounted) setState(() {});
        },
        icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
      );
    }

    Widget endWidget = Text(
      'Type "${widget.type}" not implemented',
      style: const TextStyle(color: Colors.orange),
    );
    TextInputType keyboardType = TextInputType.text;
    TextInputAction? textInputAction = widget.textInputAction;
    List<TextInputFormatter> inputFormatters = [];
    final inputValidation = InputValidation(locales: locales);
    switch (widget.type) {
      case InputDataType.text:
        keyboardType = TextInputType.multiline;
        textInputAction = widget.textInputAction ?? TextInputAction.newline;
        break;

      case InputDataType.phone:
        // https://en.wikipedia.org/wiki/Telephone_numbering_plan
        maxLength = 16;
        hintTextDefault = '+1 (222) 333 - 4444';
        keyboardType = TextInputType.phone;
        inputFormatters.addAll([
          FilteringTextInputFormatter.deny(RegExp(r'[\s()-]')),
          FilteringTextInputFormatter.allow(RegExp(r'^\+\d{0,15}')),
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
        keyboardType = TextInputType.datetime;
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
        ]);
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

    String? hintText = widget.hintText ?? hintTextDefault;
    final inputDecoration = InputDecoration(
      hintText:
          (value?.toString() ?? '').isNotEmpty ? value?.toString() : hintText,
      isDense: isDense,
      errorText: errorText,
      errorMaxLines: 2,
      enabled: !widget.disabled,
      prefix: widget.prefix,
      suffix: widget.suffix,
      prefixIcon: widget.prefixIcon ?? inputIcon,
      suffixIcon: widget.suffixIcon ?? inputTrailingIcon,
      prefixText: widget.prefixText,
      suffixText: widget.suffixText,
      prefixStyle: widget.prefixStyle,
      suffixStyle: widget.suffixStyle,
      labelText: widget.label,
      labelStyle: theme.textTheme.bodyMedium,
      // floatingLabelBehavior: FloatingLabelBehavior.always,
      // helperText: defaultText,
      // constraints: const BoxConstraints(maxWidth: double.maxFinite, maxHeight: double.maxFinite),
      // constraints: isDense ? const BoxConstraints(minHeight: 30) : null,
      contentPadding: isDense
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 4)
          : widget.padding,
      // constraints: BoxConstraints(minHeight: minHeight),
    );

    switch (widget.type) {
      case InputDataType.double:
      case InputDataType.int:
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
          onChanged: (newValue) {
            dynamic newFormattedValue = valueChanged(newValue);
            bool sameValue = value == newFormattedValue;
            if (!sameValue) {
              value = newFormattedValue?.toString() ?? '';
              if (widget.onChanged != null) {
                widget.onChanged!(newFormattedValue);
              }
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
        endWidget = TextFormField(
          autofillHints: widget.autofillHints,
          enableSuggestions: false,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          controller: textController,
          readOnly: true,
          decoration: inputDecoration.copyWith(
            hintText: locales.get('label--choose-label', {
              'label': locales.get('label--date'),
            }),
            prefixIcon: inputDecoration.prefixIcon ??
                inputDecoration.prefixIcon ??
                Icon(inputDataTypeIcon(widget.type)),
          ),
          onTap: () async {
            DateTime now = DateTime.now().toUtc();
            DateTime date = value ?? now;
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
            } else if (widget.type == InputDataType.dateTime) {
              picked = await showDialog<DateTime?>(
                context: context,
                barrierDismissible: false, // user must tap button!
                builder: (BuildContext context) {
                  DateTime? tempDate;
                  return AlertDialog(
                    contentPadding: EdgeInsets.zero,
                    clipBehavior: Clip.hardEdge,
                    content: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 300,
                        minHeight: 300,
                        minWidth: 360,
                        maxWidth: 500,
                      ),
                      child: CupertinoDatePicker(
                        // use24hFormat: true,
                        initialDateTime: date,
                        minimumDate: minDate,
                        maximumDate: maxDate,
                        // use24hFormat: true,
                        // This is called when the user changes the dateTime.
                        onDateTimeChanged: (DateTime newDateTime) {
                          tempDate = newDateTime;
                        },
                        mode: CupertinoDatePickerMode.dateAndTime,
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: Text(locales.get('label--cancel')),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      ElevatedButton(
                        child: Text(locales.get('label--update')),
                        onPressed: () {
                          Navigator.of(context).pop(tempDate);
                        },
                      ),
                    ],
                  );
                },
              );
            }
            if (picked != null) {
              final newDate = Utils.dateTimeOffset(
                dateTime: picked,
                utcOffset: widget.utcOffset,
                reverse: true,
              );
              if (widget.onChanged != null) widget.onChanged!(newDate);
              if (widget.onComplete != null) widget.onComplete!(newDate);
              if (widget.onSubmit != null) widget.onSubmit!(newDate);
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
        endWidget = ElevatedButton.icon(
          onPressed: isDisabled
              ? null
              : () async {
                  time ??= TimeOfDay.now();
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: time!,
                  );
                  if (picked != null && picked != time) {
                    if (widget.onChanged != null) widget.onChanged!(picked);
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
            hintText: widget.hintText ?? hintTextDefault,
            prefixIcon: inputDecoration.prefixIcon ??
                inputDecoration.prefixIcon ??
                Icon(inputDataTypeIcon(widget.type)),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          onTap: isDisabled
              ? null
              : () async {
                  searchController.openView();
                },
        );
        if (!isDisabled) {
          endWidget = SearchAnchor(
            searchController: searchController,
            builder: (BuildContext context, SearchController controller) {
              return widgetInput;
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
                  final valueMatch =
                      element.value.toString().contains(value.toLowerCase());
                  return labelMatch || valueMatch || labelAltMatch;
                }).toList();
              }
              return List<ListTile>.generate(recommendations.length,
                  (int index) {
                final item = recommendations[index];
                return ListTile(
                  title: Text(item.label),
                  onTap: () {
                    controller.closeView('');
                    if (widget.onChanged != null && item.value != value) {
                      widget.onChanged!(item.value);
                    }
                    if (widget.onChanged != null) {
                      widget.onChanged!(item.value == '' ? null : item.value);
                    }
                    if (widget.onComplete != null) {
                      widget.onComplete!(item.value);
                    }
                    if (widget.onSubmit != null) widget.onSubmit!(item.value);
                    // if (mounted) setState(() {});
                  },
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
              if (mounted) setState(() {});
              if (widget.onChanged != null) widget.onChanged!(value);
              if (widget.onComplete != null) widget.onComplete!(value);
              if (widget.onSubmit != null) widget.onSubmit!(value);
            },
          );
          // return ListTile(
          //   title: Text(e.label),
          //   leading: Radio<String?>(
          //     value: e.value?.toString(),
          //     groupValue: value?.toString(),
          //     onChanged: (String? value) {
          //       if (widget.onChanged != null) {
          //         widget.onChanged!(value == '' ? null : value);
          //       }
          //     },
          //   ),
          //   onTap: () {
          //     if (widget.onChanged != null) {
          //       widget.onChanged!(e.value?.toString() == '' ? null : e.value);
          //     }
          //   },
          // );
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
            floatingLabelBehavior: FloatingLabelBehavior.never,
            hintText: widget.label ?? widget.hintText,
            labelText: null,
            prefixIcon: inputDecoration.prefixIcon ??
                Icon(inputDataTypeIcon(widget.type)),
            suffixIcon: Switch(
              value: value,
              onChanged: (newValue) {
                value = newValue;
                if (widget.onChanged != null) widget.onChanged!(value);
                if (widget.onComplete != null) widget.onComplete!(value);
                if (widget.onSubmit != null) widget.onSubmit!(value);
              },
            ),
          ),
          onTap: () async {
            value = !value;
            if (widget.onChanged != null) widget.onChanged!(value);
            if (widget.onComplete != null) widget.onComplete!(value);
            if (widget.onSubmit != null) widget.onSubmit!(value);
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
