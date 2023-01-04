import 'package:fabric_flutter/helper/enum_data.dart';
import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/format_data.dart';
import '../helper/options.dart';
import '../serialized/filter_data.dart';
import 'input_data.dart';
import 'popup_entry.dart';

/// FilterMenuOption
class FilterMenuOption extends StatefulWidget {
  const FilterMenuOption({
    Key? key,
    required this.data,
    required this.onChange,
    required this.onDelete,
  }) : super(key: key);
  final FilterData data;
  final ValueChanged<FilterData> onChange;
  final VoidCallback onDelete;

  @override
  State<FilterMenuOption> createState() => _FilterMenuOptionState();
}

class _FilterMenuOptionState extends State<FilterMenuOption> {
  late FilterData data;

  @override
  void initState() {
    data = widget.data;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant FilterMenuOption oldWidget) {
    data = widget.data;
    if (mounted) setState(() {});
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context)!;
    final enumData = EnumData(locales: locales);

    /// Define Dropdown options depending on the InputDataType
    List<dynamic> dropdownOptions = FilterOperator.values;
    final filterOperatorTimeOrDate = [
      FilterOperator.equal,
      FilterOperator.notEqual,
      // FilterOperator.contains,
      FilterOperator.greaterThan,
      FilterOperator.lessThan,
      FilterOperator.between,
      FilterOperator.any,
    ];
    final filterOperatorExact = [
      FilterOperator.equal,
      FilterOperator.notEqual,
      // FilterOperator.contains,
      // FilterOperator.greaterThan,
      // FilterOperator.lessThan,
      // FilterOperator.between,
      FilterOperator.any,
    ];

    switch (data.type) {
      case InputDataType.email:
      case InputDataType.enums:
      case InputDataType.dropdown:
      case InputDataType.radio:
        dropdownOptions = filterOperatorExact;
        break;
      case InputDataType.date:
      case InputDataType.time:
        dropdownOptions = filterOperatorTimeOrDate;
        break;
      default:
    }

    /// Label value
    String dataOperatorString = enumData.localesFromEnum(data.operator);
    String label = data.label;
    if (data.operator != FilterOperator.contains) {
      label += ' ${locales.get('label--is')}';
    }
    label += ' $dataOperatorString';

    if (data.operator != FilterOperator.any) {
      label += ': ';
      try {
        switch (data.type) {
          case InputDataType.date:
            if (data.operator == FilterOperator.between) {
              label += FormatData.formatDateShort().format(data.value[0]);
              label += ' ${locales.get('label--and')} ';
              label += FormatData.formatDateShort().format(data.value[1]);
            } else {
              label += FormatData.formatDateShort().format(data.value);
            }
            break;
          case InputDataType.time:
            if (data.operator == FilterOperator.between) {
              label += data.value[0].format(context);
              label += ' ${locales.get('label--and')} ';
              label += data.value[1].format(context);
            } else {
              label += data.value.format(context);
            }
            break;
          case InputDataType.email:
          case InputDataType.double:
          case InputDataType.int:
          case InputDataType.text:
          case InputDataType.string:
          case InputDataType.phone:
          case InputDataType.url:
            if (data.operator == FilterOperator.between) {
              label += data.value[0].toString();
              label += ' ${locales.get('label--and')} ';
              label += data.value[1].toString();
            } else {
              label += data.value.toString();
            }
            break;
          case InputDataType.enums:
            label += enumData.localesFromEnum(data.value);
            break;
          case InputDataType.dropdown:
          case InputDataType.radio:
            label += data.options
                .firstWhere((element) => element.value == data.value,
                    orElse: () => ButtonOptions())
                .label;
            break;
          case InputDataType.secret:
            label += '***';
            break;
        }
      } catch (e) {
        //
      }
    }
    const space = SizedBox(height: 16);

    return PopupMenuButton(
      tooltip: locales.get(
        'label--edit-label',
        {'label': data.label},
      ),
      padding: EdgeInsets.zero,
      onCanceled: () {
        if (mounted) setState(() {});
      },
      itemBuilder: (BuildContext context) {
        FilterData? edit;
        edit ??= FilterData.fromJson(data.toJson());
        return [
          PopupEntry(
            child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              late Widget optionInput;
              switch (edit!.operator) {
                case FilterOperator.equal:
                case FilterOperator.notEqual:
                case FilterOperator.contains:
                case FilterOperator.lessThan:
                case FilterOperator.greaterThan:
                  optionInput = InputData(
                    label: locales.get('label--value'),
                    type: data.type,
                    value: edit.value,
                    enums: data.enums,
                    options: data.options,
                    onChanged: (value) {
                      edit!.value = value;
                      if (mounted) setState(() {});
                    },
                  );
                  break;
                case FilterOperator.between:
                  optionInput = Flex(
                    direction: Axis.vertical,
                    children: [
                      InputData(
                        label: '${locales.get('label--value')} 1',
                        type: data.type,
                        value: edit.value?[0],
                        enums: data.enums,
                        options: data.options,
                        onChanged: (value) {
                          edit!.value = [value, edit.value?[1]];
                          if (mounted) setState(() {});
                        },
                      ),
                      space,
                      InputData(
                        label: '${locales.get('label--value')} 2',
                        type: data.type,
                        value: edit.value?[1],
                        enums: data.enums,
                        options: data.options,
                        onChanged: (value) {
                          edit!.value = [edit.value?[0], value];
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  );
                  break;
                case FilterOperator.any:
                  optionInput = const SizedBox();
                  break;
                default:
              }
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Flex(
                  direction: Axis.vertical,
                  children: [
                    InputData(
                      label: data.label,
                      type: InputDataType.enums,
                      enums: dropdownOptions,
                      onChanged: (value) {
                        edit!.operator = value ?? FilterOperator.any;
                        edit.value =
                            edit.operator == FilterOperator.any ? true : null;
                        if (mounted) setState(() {});
                      },
                      value: edit.operator,
                    ),
                    space,
                    optionInput,
                    space,
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            if (mounted) setState(() {});
                            Navigator.of(context).pop();
                          },
                          child: Text(locales.get('label--cancel')),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: edit.value == null || edit.operator == null
                              ? null
                              : () {
                                  data.operator = edit!.operator;
                                  data.value = edit.value;
                                  Navigator.of(context).pop();
                                  widget.onChange(data);
                                },
                          child: Text(locales.get('label--apply')),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        ];
      },
      child: Chip(
        label: Text(label),
        avatar: Icon(
          inputDataTypeIcon(data.type),
          color: Colors.grey,
        ),
        onDeleted: widget.onDelete,
        deleteButtonTooltipMessage: locales.get(
          'label--clear-label',
          {'label': locales.get('label--filter')},
        ),
      ),
    );
  }
}

/// FilterMenu
class FilterMenu extends StatefulWidget {
  const FilterMenu({
    Key? key,
    required this.data,
    required this.onChange,
    this.child,
    this.icon,
    this.iconClear,
  }) : super(key: key);
  final List<FilterData> data;
  final ValueChanged<List<FilterData>> onChange;

  /// If provided, [child] is the widget used for this button
  /// and the button will utilize an [InkWell] for taps.
  final Widget? child;

  /// If provided, the [icon] is used for this button
  /// and the button will behave like an [IconButton].
  final Widget? icon;

  /// If provided, the [icon] is used for this button
  /// and the button will behave like an [IconButton].
  final Widget? iconClear;

  @override
  State<FilterMenu> createState() => _FilterMenuState();
}

class _FilterMenuState extends State<FilterMenu> {
  late List<FilterData> data;

  @override
  void initState() {
    data = widget.data;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant FilterMenu oldWidget) {
    data = widget.data;
    if (mounted) setState(() {});
    super.didUpdateWidget(oldWidget);
  }

  void clear() {
    data = widget.data.map((e) {
      FilterData item = e;
      item.operator = null;
      item.value = null;
      item.index = 0;
      return item;
    }).toList();
    widget.onChange(data);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    assert(
      !(widget.child != null && widget.icon != null),
      'You can only pass [child] or [icon], not both.',
    );
    final locales = AppLocalizations.of(context)!;

    /// Ignore options that are included on the filters data
    List<FilterData> pendingOptions =
        data.where((element) => element.value == null).toList();
    List<FilterData> activeOptions =
        data.where((element) => element.value != null).toList();
    activeOptions.sort((a, b) => a.index.compareTo(b.index));

    List<PopupMenuEntry<String>> buttons =
        List.generate(pendingOptions.length, (index) {
      final item = pendingOptions[index];
      FilterData selected =
          data.singleWhere((element) => element.id == item.id);
      return PopupMenuItem<String>(
        value: item.id,
        onTap: () {
          selected.operator = FilterOperator.any;
          selected.value = true;
          selected.index = activeOptions.length + 1;
          if (mounted) setState(() {});
          // Do not call onChange or it will trigger unwanted calls
          // if (selected.onChange != null) selected.onChange!(selected);
          // widget.onChange(data);
        },
        child: ListTile(
          title: Text(
            item.label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          trailing: Icon(inputDataTypeIcon(selected.type)),
        ),
      );
    });

    /// Menu List Options
    List<Widget> menuOptions = List.generate(activeOptions.length, (index) {
      final item = activeOptions[index];
      FilterData selected =
          data.singleWhere((element) => element.id == item.id);
      return FilterMenuOption(
        data: item,
        onChange: (value) {
          selected.operator = value.operator;
          selected.value = value.value;
          if (selected.onChange != null) selected.onChange!(selected);
          widget.onChange(data);
        },
        onDelete: () {
          selected.operator = null;
          selected.value = null;
          selected.index = 0;
          if (selected.onChange != null) selected.onChange!(selected);
          widget.onChange(data);
        },
      );
    });

    /// Add popUp button
    if (pendingOptions.isNotEmpty) {
      menuOptions.add(PopupMenuButton<String>(
        tooltip: locales.get(
          'label--add-label',
          {'label': locales.get('label--filter')},
        ),
        padding: EdgeInsets.zero,
        itemBuilder: (BuildContext context) => buttons,
        child: widget.child == null
            ? OutlinedButton.icon(
                style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.all(
                    theme.buttonTheme.colorScheme?.primary ?? Colors.black,
                  ),
                ),
                onPressed: null,
                icon: widget.icon ?? const Icon(Icons.filter_alt),
                label: Text(locales.get(
                  'label--add-label',
                  {'label': locales.get('label--filters')},
                )),
              )
            : null,
      ));
    }
    if (activeOptions.isNotEmpty) {
      menuOptions.add(OutlinedButton.icon(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all(Colors.red),
        ),
        onPressed: clear,
        icon: widget.iconClear ?? const Icon(Icons.clear),
        label: Text(locales.get(
          'label--clear-label',
          {'label': locales.get('label--filters')},
        )),
      ));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: menuOptions,
    );
  }
}