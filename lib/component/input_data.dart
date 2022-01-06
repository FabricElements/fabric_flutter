import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/enum_data.dart';
import '../helper/options.dart';
import '../helper/utils.dart';

/// [InputDataType] defines the supported types for the [InputData] component
enum InputDataType {
  date,
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
    this.expanded = false,
    this.padding = EdgeInsets.zero,
    this.utcOffset,
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
  final bool expanded;
  final EdgeInsets padding;
  final num? utcOffset;

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
  dynamic value;

  void getValue({bool notify = false, required dynamic newValue}) {
    switch (widget.type) {
      case InputDataType.string:
      case InputDataType.double:
      case InputDataType.int:
      case InputDataType.text:
      case InputDataType.radio:
      case InputDataType.phone:
        String _tempValue = newValue != null ? newValue.toString() : "";
        if (_tempValue != value) {
          value = _tempValue;
          textController.text = value;
        }
        break;
      case InputDataType.date:
        value = Utils.dateTimeOffset(
          dateTime: newValue as DateTime?,
          utcOffset: widget.utcOffset,
          reverse: true,
        );
        break;
      case InputDataType.time:
        value = newValue as TimeOfDay?;
        break;
      default:
        value = newValue;
    }
    if (notify && mounted) setState(() {});
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
    bool _disabled = widget.disabled;
    String _defaultText =
        widget.textDefault ?? locales.get("label--choose-option");
    String textSelected = _defaultText;
    String? hintTextDefault;
    int? maxLength = widget.maxLength;
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
        if (widget.expanded) {
          maxWidth = widget.expanded ? double.maxFinite : maxWidth;
        }
        Widget _widget = Text(
          "Type '${widget.type}' not implemented",
          style: TextStyle(color: Colors.orange),
        );
        TextInputType keyboardType = TextInputType.text;
        List<TextInputFormatter> inputFormatters = [];
        switch (widget.type) {
          case InputDataType.phone:

            /// https://en.wikipedia.org/wiki/Telephone_numbering_plan
            maxLength = 16;
            hintTextDefault = "+1 (222) 333 - 4444";
            keyboardType = const TextInputType.numberWithOptions(
                decimal: true, signed: true);
            inputFormatters.addAll([
              FilteringTextInputFormatter.deny(RegExp(r'[\s()-]'),
                  replacementString: ""),
              FilteringTextInputFormatter.allow(RegExp(r'^\+\d{0,15}'),
                  replacementString: ""),
              FilteringTextInputFormatter.singleLineFormatter,
            ]);
            break;
          case InputDataType.double:
            keyboardType = const TextInputType.numberWithOptions(decimal: true);
            inputFormatters.addAll([
              FilteringTextInputFormatter.singleLineFormatter,
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ]);
            break;
          case InputDataType.int:
            keyboardType = TextInputType.number;
            inputFormatters.addAll([
              FilteringTextInputFormatter.singleLineFormatter,
              FilteringTextInputFormatter.digitsOnly,
            ]);
            break;
          default:
        }

        /// Format New Value
        dynamic _valueChanged(String? valueLocal) {
          String? _value =
              valueLocal != null && valueLocal.isNotEmpty ? valueLocal : null;
          switch (widget.type) {
            case InputDataType.double:
              return double.parse(_value ?? "0");
            case InputDataType.int:
              return int.parse(_value ?? "0");
            default:
              return _value;
          }
        }

        switch (widget.type) {
          case InputDataType.double:
          case InputDataType.int:
          case InputDataType.string:
          case InputDataType.text:
          case InputDataType.phone:
            _widget = TextFormField(
              controller: textController,
              enableSuggestions: false,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              maxLines: widget.type == InputDataType.text ? 10 : 1,
              minLines: 1,
              maxLength: maxLength,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                fillColor: Colors.white,
                filled: true,
                hintText: widget.hintText ?? hintTextDefault ?? value,
                isDense: widget.isDense,
              ),
              onChanged: (newValue) {
                value = newValue;
                if (widget.onChanged != null)
                  widget.onChanged!(_valueChanged(newValue));
              },
              onFieldSubmitted: (newValue) {
                if (widget.onSubmit != null)
                  widget.onSubmit!(_valueChanged(newValue));
              },
              onEditingComplete: () {
                if (widget.onSubmit != null)
                  widget.onSubmit!(_valueChanged(value));
              },
            );
            break;
          case InputDataType.date:
            DateTime? _date = value as DateTime?;
            DateFormat formatDate = new DateFormat.yMd("en_US");
            final _baseDateFormat = Utils.dateTimeOffset(
              dateTime: _date,
              utcOffset: widget.utcOffset,
            );
            String label = _date != null
                ? formatDate.format(_baseDateFormat!)
                : locales.get("label--choose-label", {
                    "label": locales.get("label--date"),
                  });
            _widget = Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (_date == null) _date = DateTime.now();
                  int _year = _date!.year < 2020 ? _date!.year : 2000;
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _date!,
                    firstDate: DateTime(_year),
                    lastDate: _date!.add(Duration(days: 365)),
                  );
                  if (picked != null) {
                    final _newDate = Utils.dateTimeOffset(
                      dateTime: picked,
                      utcOffset: widget.utcOffset,
                    );
                    if (widget.onChanged != null) widget.onChanged!(_newDate);
                  }
                },
                icon: Icon(Icons.date_range),
                label: Text(label),
              ),
            );
            break;
          case InputDataType.time:
            TimeOfDay? _time = value;
            DateFormat formatTime = new DateFormat.jm();
            String label = _time != null
                ? formatTime.format(DateTime(1, 1, 1, _time.hour, _time.minute))
                : locales.get("label--choose-label", {
                    "label": locales.get("label--time"),
                  });
            _widget = Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (_time == null) _time = TimeOfDay.now();
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: _time!,
                    initialEntryMode: TimePickerEntryMode.input,
                  );
                  if (picked != null && picked != _time) if (widget.onChanged !=
                      null) widget.onChanged!(picked);
                },
                icon: Icon(Icons.access_time),
                label: Text(label),
              ),
            );
            break;
          case InputDataType.enums:
          case InputDataType.dropdown:
            List<ButtonOptions> _dropdown = [];
            List<PopupMenuEntry<String>> buttons = [
              PopupMenuItem<String>(
                value: "",
                child: Text(_defaultText),
              ),
            ];
            if (widget.type == InputDataType.dropdown) {
              _dropdown = widget.options;
            }
            if (widget.type == InputDataType.enums) {
              _dropdown = widget.enums
                  .map((e) => ButtonOptions(
                        label: enumData.localesFromEnum(e),
                        value: e,
                      ))
                  .toList();
            }
            for (ButtonOptions _option in _dropdown) {
              buttons.add(PopupMenuItem<String>(
                value: _option.value?.toString(),
                child: Text(_option.label),
              ));
            }
            if (value != null) {
              if (widget.type == InputDataType.enums &&
                  widget.enums.firstWhereOrNull((e) => e == value) != null) {
                textSelected = enumData.localesFromEnum(value);
              }
              if (widget.type == InputDataType.dropdown) {
                textSelected = widget.options
                    .firstWhere((element) => element.value == value)
                    .label;
              }
            }
            if (buttons.length == 1) {
              _disabled = true;
            }
            _widget = PopupMenuButton<String>(
              enabled: !_disabled,
              elevation: 1,
              // isDense: isDense,
              offset: Offset(0, 40),
              key: popupButtonKey,
              initialValue: value?.toString(),
              onSelected: (_value) {
                if (widget.onChanged != null)
                  widget.onChanged!(_value == "" ? null : _value);
              },
              child: ListTile(
                title: Text(textSelected),
                trailing: Icon(
                  Icons.arrow_drop_down,
                  color: _disabled
                      ? Colors.grey.shade300
                      : theme.colorScheme.primary,
                ),
                mouseCursor: _disabled
                    ? SystemMouseCursors.forbidden
                    : SystemMouseCursors.click,
              ),
              itemBuilder: (BuildContext context) => buttons,
            );

            break;
          case InputDataType.radio:
            List<Widget> _options = widget.options.map((e) {
              return ListTile(
                title: Text(e.label),
                leading: Radio<String?>(
                  value: e.value?.toString(),
                  groupValue: value?.toString(),
                  onChanged: (String? value) {
                    if (widget.onChanged != null)
                      widget.onChanged!(value == "" ? null : value);
                  },
                ),
                onTap: () {
                  if (widget.onChanged != null)
                    widget.onChanged!(
                      e.value?.toString() == "" ? null : e.value?.toString(),
                    );
                },
              );
            }).toList();
            _widget = Column(
              children: _options,
            );
            break;
          default:
        }
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: widget.padding,
            child: _widget,
          ),
        );
      },
    );
  }
}
