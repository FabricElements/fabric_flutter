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
    Key? key,
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
  }) : super(key: key);
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
  final num? utcOffset;
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
  DateFormat formatDate = DateFormat.yMd('en_US');
  DateFormat formatDateTime =
      DateFormat.yMd('en_US').addPattern(' - ').add_jm();
  dynamic value;
  late bool obscureText;

  /// Get Value from parameter
  void getValue({bool notify = false, required dynamic newValue}) {
    try {
      switch (widget.type) {
        case InputDataType.string:
        case InputDataType.double:
        case InputDataType.int:
        case InputDataType.text:
        case InputDataType.phone:
        case InputDataType.email:
        case InputDataType.secret:
        case InputDataType.url:
          String tempValue = newValue?.toString() ?? '';
          if (tempValue != value) {
            value = tempValue;
            textController.text = value?.toString() ?? '';
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
          break;
        case InputDataType.dropdown:
          bool valueInOptions = widget.options.where((item) {
            return item.value == newValue;
          }).isNotEmpty;
          if (valueInOptions) {
            value = newValue;
          } else {
            value = null;
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
          break;
        default:
          value = newValue;
      }
      if (notify && mounted) setState(() {});
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
    obscureText = widget.obscureText;
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
    AppLocalizations locales = AppLocalizations.of(context)!;
    final popupButtonKey = GlobalKey<State>();
    final enumData = EnumData(locales: locales);
    ThemeData theme = Theme.of(context);
    bool isDense = widget.isDense || theme.inputDecorationTheme.isDense;
    bool isDisabled = widget.disabled;
    String defaultTextOptions = locales.get('label--choose-option');
    // String textSelected = defaultText;
    String? hintTextDefault;
    int? maxLength = widget.maxLength;
    FormFieldValidator<String>? validator = widget.validator;
    Widget? icon = widget.icon != null ? Icon(widget.icon) : null;

    /// Text styles
    String? errorText;
    // TextStyle? labelStyle;
    // InputBorder? border;
    // InputBorder? focusedBorder;
    if (widget.error != null) {
      errorText = widget.error;
      // labelStyle = theme.inputDecorationTheme.errorStyle;
      // border = theme.inputDecorationTheme.errorBorder;
      // focusedBorder = theme.inputDecorationTheme.focusedErrorBorder;
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
    if (widget.obscureText) {
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

        /// https://en.wikipedia.org/wiki/Telephone_numbering_plan
        maxLength = 16;
        hintTextDefault = '+1 (222) 333 - 4444';
        keyboardType = const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        );
        inputFormatters.addAll([
          FilteringTextInputFormatter.deny(RegExp(r'[\s()-]'),
              replacementString: ''),
          FilteringTextInputFormatter.allow(RegExp(r'^\+\d{0,15}'),
              replacementString: ''),
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
        keyboardType = const TextInputType.numberWithOptions(decimal: true);
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
          FilteringTextInputFormatter.allow(
              RegExp(r'^[0-9]+([.]?)+([0-9]+)?$')),
        ]);
        break;
      case InputDataType.int:
        keyboardType = TextInputType.number;
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
          FilteringTextInputFormatter.digitsOnly,
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
      prefixIcon: inputIcon,
      suffixIcon: inputTrailingIcon,
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

    /// Format New Value
    dynamic valueChanged(dynamic valueLocal) {
      if (valueLocal == null) return null;
      String valueLocalString = valueLocal!.toString();
      if (valueLocalString.isEmpty) return null;
      switch (widget.type) {
        case InputDataType.double:
          if (valueLocalString.endsWith('.')) {
            valueLocalString =
                valueLocalString.replaceFirst(RegExp('.'), ''); // h*llo hello
          }
          return double.tryParse(valueLocalString);
        case InputDataType.int:
          return int.tryParse(valueLocalString);
        default:
          return valueLocal;
      }
    }

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
            value = newValue;
            if (widget.onChanged != null) {
              widget.onChanged!(valueChanged(value));
            }
          },
          onFieldSubmitted: widget.onSubmit == null
              ? null
              : (newValue) {
                  value = newValue;
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
            final minDate = dateBefore.subtract(const Duration(days: 365 * 10));
            final maxDate = dateAfter.add(const Duration(days: 365 * 10));
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
        }
        if (widget.type == InputDataType.enums) {
          dropdownOptions = List.generate(widget.enums.length, (index) {
            final e = widget.enums[index];
            return ButtonOptions(
              label: enumData.localesFromEnum(e),
              value: e,
            );
          });
        }
        List<DropdownMenuItem<dynamic>> buttons = [
          DropdownMenuItem(
            value: '',
            child: Text(
              hintText ?? defaultTextOptions,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              maxLines: 1,
            ),
          ),
        ];
        buttons.addAll(List.generate(dropdownOptions.length, (index) {
          final option = dropdownOptions[index];
          return DropdownMenuItem(
            value: option.value,
            onTap:
                option.onTap != null ? () => option.onTap!(option.value) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 100, maxWidth: 190),
              child: Text(
                option.label,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                maxLines: 1,
              ),
            ),
          );
        }));
        if (buttons.length == 1) {
          isDisabled = true;
        }
        endWidget = DropdownButtonFormField<dynamic>(
          hint: widget.hintText != null ? Text(widget.hintText!) : null,
          isExpanded: widget.isExpanded,
          isDense: true,
          icon: icon,
          elevation: 1,
          key: popupButtonKey,
          value: value,
          onChanged: isDisabled
              ? null
              : (dynamic newValue) {
                  if (widget.onChanged != null) {
                    widget.onChanged!(newValue == '' ? null : newValue);
                  }
                  if (widget.onComplete != null) widget.onComplete!(newValue);
                  if (widget.onSubmit != null) widget.onSubmit!(newValue);
                },
          items: buttons,
          decoration: inputDecoration,
          style: widget.textStyle,
        );
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
