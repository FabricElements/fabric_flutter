import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/enum_data.dart';
import '../helper/options.dart';

/// [InputDataType] defines the supported types for the [InputData] component
enum InputDataType {
  date,
  double,
  int,
  text,
  enums,
  dropdown,
  string,
}

/// [InputData] provides an useful way to handle data input
/// It's much faster to use this component because includes all the controllers
/// you require for multiple data types [InputDataType]
class InputData extends StatelessWidget {
  const InputData({
    Key? key,
    required this.value,
    required this.type,
    this.enums = const [],
    this.dropdown = const [],
    required this.onChanged,
    this.disabled = false,
    this.hintText,
    this.maxLength = 255,
    this.textDefault,
  }) : super(key: key);
  final dynamic value;
  final List<dynamic> enums;
  final List<ButtonOptions> dropdown;
  final InputDataType type;
  final bool disabled;
  final String? hintText;
  final String? textDefault;
  final int maxLength;

  /// [onChanged]
  /// Never use expression body or value won't be update correctly
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    AppLocalizations locales = AppLocalizations.of(context)!;
    final popupButtonKey = GlobalKey<State>();
    EnumData enumData = EnumData(locales: locales);
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    bool _disabled = disabled;
    String _defaultText = textDefault ?? locales.get("label--choose-option");
    String textSelected = _defaultText;
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
          Widget _widget = Text("Type '$type' not implemented",
          style: TextStyle(color: Colors.orange));
      TextInputType keyboardType = TextInputType.text;
      List<TextInputFormatter> inputFormatters = [];
      switch (type) {
        case InputDataType.double:
          keyboardType = const TextInputType.numberWithOptions(decimal: true);
          inputFormatters
              .add(FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')));
          break;
        case InputDataType.int:
          keyboardType = TextInputType.number;
          inputFormatters.add(FilteringTextInputFormatter.digitsOnly);
          break;
        default:
      }
      switch (type) {
        case InputDataType.double:
        case InputDataType.int:
        case InputDataType.string:
        case InputDataType.text:
          String _value = value != null ? value.toString() : "";
          _widget = TextFormField(
            enableSuggestions: false,
            keyboardType: keyboardType,
            initialValue: _value,
            inputFormatters: inputFormatters,
            maxLines: type == InputDataType.text ? 10 : 1,
            minLines: 1,
            maxLength: maxLength,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(16),
              fillColor: Colors.white,
              filled: true,
              hintText: hintText ?? _value,
            ),
            onChanged: (valueLocal) {
              String _value = valueLocal.isNotEmpty ? valueLocal : "0";
              if (type == InputDataType.double) {
                onChanged(double.parse(_value));
              }
              if (type == InputDataType.int) {
                onChanged(int.parse(_value));
              }
            },
          );
          break;
        case InputDataType.date:
          DateTime? _date = value as DateTime?;
          DateFormat formatDate = new DateFormat.yMd("en_US");
          String label = _date != null
              ? formatDate.format(value)
              : locales.get("label--choose-date");
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
                if (picked != null && picked != _date) onChanged(picked);
              },
              icon: Icon(Icons.date_range),
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
          if (type == InputDataType.dropdown) {
            _dropdown = dropdown;
          }
          if (type == InputDataType.enums) {
            _dropdown = enums
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
            if (type == InputDataType.enums) {
              textSelected = enumData.localesFromEnum(value);
            }
            if (type == InputDataType.dropdown) {
              textSelected = dropdown
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
            offset: Offset(0, 40),
            key: popupButtonKey,
            initialValue: value?.toString(),
            onSelected: (_value) {
              onChanged(_value == "" ? null : _value);
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
        default:
      }
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: _widget,
      );
    });
  }
}
