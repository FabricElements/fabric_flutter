import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/enum_data.dart';
import '../helper/input_validation.dart';
import '../helper/options.dart';
import '../helper/utils.dart';

/// [InputDataType] defines the supported types for the [InputData] component
enum InputDataType {
  date,
  email,
  time,
  double,
  int,
  text,
  enums,
  dropdown,
  string,
  radio,
  phone,
}

/// [InputData] provides an useful way to handle data input
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
    this.disabled = false,
    this.hintText,
    this.isDense = false,
    this.maxLength = 255,
    this.textDefault,
    this.isExpanded = false,
    this.padding = EdgeInsets.zero,
    this.utcOffset,
    this.validator,
    this.backgroundColor,
    this.icon,
    this.error,
  }) : super(key: key);
  final dynamic value;
  final List<dynamic> enums;
  final List<ButtonOptions> options;
  final InputDataType type;
  final bool disabled;
  final String? hintText;
  final String? textDefault;
  final int maxLength;
  final bool isDense;
  final bool isExpanded;
  final EdgeInsets padding;
  final num? utcOffset;
  final FormFieldValidator<String>? validator;
  final Color? backgroundColor;
  final IconData? icon;
  final String? error;

  /// [onSubmit]
  /// Never use expression body or value won't be update correctly
  final ValueChanged<dynamic>? onSubmit;

  /// [onChanged]
  /// Never use expression body or value won't be update correctly
  final ValueChanged<dynamic>? onChanged;

  @override
  State<InputData> createState() => _InputDataState();
}

class _InputDataState extends State<InputData> {
  TextEditingController textController = TextEditingController();
  DateFormat formatDate = DateFormat.yMd('en_US');
  dynamic value;

  /// Get Value from parameter
  void getValue({bool notify = false, required dynamic newValue}) {
    try {
      switch (widget.type) {
        case InputDataType.string:
        case InputDataType.double:
        case InputDataType.int:
        case InputDataType.text:
        case InputDataType.radio:
        case InputDataType.phone:
        case InputDataType.email:
          String tempValue = newValue?.toString() ?? '';
          if (tempValue != value) {
            value = tempValue;
            textController.text = value;
            if (notify && mounted) setState(() {});
          }
          break;
        case InputDataType.date:
          value = newValue as DateTime?;
          if (value != null) {
            value = Utils.dateTimeOffset(
              dateTime: value,
              utcOffset: widget.utcOffset,
              reverse: true,
            );
            textController.text = formatDate.format(value);
          } else {
            textController.text = '';
          }
          if (notify && mounted) setState(() {});
          break;
        case InputDataType.time:
          value = newValue as TimeOfDay?;
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
    getValue(newValue: widget.value);
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
    EnumData enumData = EnumData(locales: locales);
    ThemeData theme = Theme.of(context);
    bool isDisabled = widget.disabled;
    String defaultText =
        widget.textDefault ?? locales.get('label--choose-option');
    String textSelected = defaultText;
    String? hintTextDefault;
    int? maxLength = widget.maxLength;
    FormFieldValidator<String>? validator = widget.validator;
    Widget? icon = widget.icon != null ? Icon(widget.icon) : null;
    final ButtonThemeData buttonTheme = ButtonTheme.of(context);
    final PopupMenuThemeData popupMenuTheme = PopupMenuTheme.of(context);

    /// Text styles
    String? errorText;
    TextStyle? labelStyle;
    InputBorder? border;
    InputBorder? focusedBorder;
    if (widget.error != null) {
      labelStyle = theme.inputDecorationTheme.errorStyle;
      errorText = widget.error;
      border = theme.inputDecorationTheme.errorBorder;
      focusedBorder = theme.inputDecorationTheme.focusedErrorBorder;
    }

    InputDecoration inputDecoration = InputDecoration(
      hintText: value?.toString() ??
          widget.hintText ??
          hintTextDefault ??
          defaultText,
      isDense: widget.isDense,
      errorText: errorText,
      enabled: !widget.disabled,
      prefixIcon: widget.icon != null ? Icon(widget.icon) : null,
      // helperText: defaultText,
    );

    /// Base
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double width = constraints.maxWidth.floorToDouble();
        int layoutTo = 2;
        if (width > 600) layoutTo = 3;
        if (width > 900) layoutTo = 4;
        if (width > 1000) layoutTo = 5;
        // if (width > 1100) layoutTo = 6;
        // if (width > 1500) layoutTo = 7;
        double maxWidth =
            (width / layoutTo) - ((layoutTo) / 2 * 8).floorToDouble();
        if (widget.isExpanded) {
          maxWidth = widget.isExpanded ? double.maxFinite : maxWidth;
        }
        Widget endWidget = Text(
          'Type "${widget.type}" not implemented',
          style: const TextStyle(color: Colors.orange),
        );
        TextInputType keyboardType = TextInputType.text;
        List<TextInputFormatter> inputFormatters = [];
        final inputValidation = InputValidation(locales: locales);
        switch (widget.type) {
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
          case InputDataType.double:
            keyboardType = const TextInputType.numberWithOptions(decimal: true);
            inputFormatters.addAll([
              FilteringTextInputFormatter.singleLineFormatter,
              FilteringTextInputFormatter.allow(RegExp(r'[\d.-]')),
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
            keyboardType = TextInputType.datetime;
            inputFormatters.addAll([
              FilteringTextInputFormatter.singleLineFormatter,
            ]);
            break;
          default:
        }

        /// Format New Value
        dynamic _valueChanged(dynamic valueLocal) {
          // dynamic _value =
          //     valueLocal != null && valueLocal.isNotEmpty ? valueLocal : null;
          switch (widget.type) {
            case InputDataType.double:
              return double.parse(valueLocal?.toString() ?? '0');
            case InputDataType.int:
              return int.parse(valueLocal?.toString() ?? '0');
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
            endWidget = TextFormField(
              controller: textController,
              enableSuggestions: false,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              validator: validator,
              autovalidateMode: AutovalidateMode.always,
              maxLines: widget.type == InputDataType.text ? 10 : 1,
              minLines: 1,
              maxLength: maxLength,
              decoration: inputDecoration,
              onChanged: (newValue) {
                value = newValue;
                if (widget.onChanged != null) {
                  widget.onChanged!(_valueChanged(newValue));
                }
              },
              onFieldSubmitted: (newValue) {
                if (widget.onSubmit != null) {
                  widget.onSubmit!(_valueChanged(newValue));
                }
              },
              onEditingComplete: () {
                if (widget.onSubmit != null) {
                  widget.onSubmit!(_valueChanged(value));
                }
              },
            );
            break;
          case InputDataType.date:
            endWidget = TextFormField(
              enableSuggestions: false,
              keyboardType: keyboardType,
              controller: textController,
              readOnly: true,
              decoration: inputDecoration.copyWith(
                hintText: locales.get('label--choose-label', {
                  'label': locales.get('label--date'),
                }),
                prefixIcon:
                    inputDecoration.prefixIcon ?? const Icon(Icons.date_range),
              ),
              onTap: () async {
                DateTime? date = value ?? DateTime.now();
                int year = date!.year < 2020 ? date.year : 2000;
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(year),
                  lastDate: date.add(const Duration(days: 365)),
                );
                if (picked != null) {
                  final newDate = Utils.dateTimeOffset(
                    dateTime: picked,
                    utcOffset: widget.utcOffset,
                  );
                  if (widget.onChanged != null) widget.onChanged!(newDate);
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
            endWidget = Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  time ??= TimeOfDay.now();
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: time!,
                    initialEntryMode: TimePickerEntryMode.input,
                  );
                  if (picked != null && picked != time) {
                    if (widget.onChanged != null) widget.onChanged!(picked);
                  }
                },
                icon: const Icon(Icons.access_time),
                label: Text(label),
              ),
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
            List<DropdownMenuItem<dynamic>> buttons =
                List.generate(dropdownOptions.length, (index) {
              final option = dropdownOptions[index];
              return DropdownMenuItem(
                value: option.value,
                onTap: option.onTap != null
                    ? () => option.onTap!(option.value)
                    : null,
                child: Text(
                  option.label,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  maxLines: 1,
                ),
              );
            });
            buttons.insert(
              0,
              DropdownMenuItem(
                  value: null,
                  child: Text(
                    defaultText,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    maxLines: 1,
                  )),
            );
            if (value != null) {
              // if (widget.type == InputDataType.enums &&
              //     widget.enums.firstWhereOrNull((e) => e == value) != null) {
              //   textSelected = enumData.localesFromEnum(value);
              // }
              if (widget.type == InputDataType.dropdown) {
                textSelected = widget.options
                    .firstWhere((element) => element.value == value)
                    .label;
              }
            }
            if (buttons.length == (widget.isDense ? 0 : 1)) {
              isDisabled = true;
            }

            endWidget = DropdownButtonFormField<dynamic>(
              isExpanded: true,
              isDense: widget.isDense,
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
                    },
              items: buttons,
              decoration: inputDecoration,
            );
            break;
          case InputDataType.radio:
            List<Widget> radioOptions =
                List.generate(widget.options.length, (index) {
              final e = widget.options[index];
              return ListTile(
                title: Text(e.label),
                leading: Radio<String?>(
                  value: e.value?.toString(),
                  groupValue: value?.toString(),
                  onChanged: (String? value) {
                    if (widget.onChanged != null) {
                      widget.onChanged!(value == '' ? null : value);
                    }
                  },
                ),
                onTap: () {
                  if (widget.onChanged != null) {
                    widget.onChanged!(
                        e.value?.toString() == '' ? null : e.value?.toString());
                  }
                },
              );
            });
            endWidget = Column(
              children: radioOptions,
            );
            break;
          default:
        }
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: widget.padding,
            child: endWidget,
          ),
        );
      },
    );
  }
}
