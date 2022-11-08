import 'package:fabric_flutter/helper/enum_data.dart';
import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../serialized/filter_data.dart';
import '../serialized/filter_options.dart';
import 'input_data.dart';
import 'popup_entry.dart';

/// TODO: Add pop when save
/// Navigator.of(context).pop()

/// FilterMenuOption
class FilterMenuOption extends StatefulWidget {
  const FilterMenuOption({
    Key? key,
    required this.option,
    required this.data,
    required this.onChange,
    required this.onDelete,
  }) : super(key: key);
  final FilterOptions option;
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
    print('updated FilterMenuOption!!!!');
    data = widget.data;
    if (mounted) setState(() {});
    super.didUpdateWidget(oldWidget);
  }

  void reset() {
    data = widget.data;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context)!;
    final enumData = EnumData(locales: locales);
    String dataOptionString = enumData.localesFromEnum(widget.data.option);
    String optionTypeString = enumData.localesFromEnum(widget.option.type);
    String label = widget.option.label;
    label += ' ${locales.get('label--is')}';
    label += ' $dataOptionString ';
    switch (widget.data.option) {
      case FilterDataOptions.equal:
        // TODO: Handle this case.
        break;
      case FilterDataOptions.notEqual:
        // TODO: Handle this case.
        break;
      case FilterDataOptions.contains:
        // TODO: Handle this case.
        break;
      case FilterDataOptions.between:
        // TODO: Handle this case.
        break;
      case FilterDataOptions.greaterThan:
        // TODO: Handle this case.
        break;
      case FilterDataOptions.lessThan:
        // TODO: Handle this case.
        break;
      case FilterDataOptions.any:
        // TODO: Handle this case.
        break;
    }

    switch (widget.option.type) {
      case InputDataType.date:
        // TODO: Handle this case.
        break;
      case InputDataType.email:
        // TODO: Handle this case.
        break;
      case InputDataType.time:
        // TODO: Handle this case.
        break;
      case InputDataType.double:
        // TODO: Handle this case.
        break;
      case InputDataType.int:
        // label += data;
        // TODO: Handle this case.
        break;
      case InputDataType.text:
        // TODO: Handle this case.
        break;
      case InputDataType.enums:
        // TODO: Handle this case.
        break;
      case InputDataType.dropdown:
        // TODO: Handle this case.
        break;
      case InputDataType.string:
        // TODO: Handle this case.
        break;
      case InputDataType.radio:
        // TODO: Handle this case.
        break;
      case InputDataType.phone:
        // TODO: Handle this case.
        break;
      case InputDataType.secret:
        // TODO: Handle this case.
        break;
      case InputDataType.url:
        // TODO: Handle this case.
        break;
    }
    // label += locales.get('');

    return PopupMenuButton(
      padding: EdgeInsets.zero,
      onCanceled: () => reset(),
      itemBuilder: (BuildContext context) {
        return [
          PopupEntry(
            child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              late Widget optionInput;
              switch (data.option) {
                case FilterDataOptions.equal:
                case FilterDataOptions.notEqual:
                case FilterDataOptions.contains:
                case FilterDataOptions.lessThan:
                case FilterDataOptions.greaterThan:
                  optionInput = InputData(
                    label: locales.get('label--value'),
                    type: widget.option.type,
                    value: data.value,
                    enums: widget.option.enums,
                    // options: widget.option.options,
                    onChanged: (value) {
                      data = FilterData(
                        id: data.id,
                        option: data.option,
                        value: value,
                      );
                      if (mounted) setState(() {});
                    },
                  );
                  break;
                case FilterDataOptions.between:
                  optionInput = Flex(
                    direction: Axis.vertical,
                    children: [
                      InputData(
                        label: '${locales.get('label--value')} 1',
                        type: widget.option.type,
                        value: data.value?[0],
                        enums: widget.option.enums,
                        // options: widget.option.options,
                        onChanged: (value) {
                          data = FilterData(
                            id: data.id,
                            option: data.option,
                            value: [value, data.value?[1]],
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                      InputData(
                        label: '${locales.get('label--value')} 2',
                        type: widget.option.type,
                        value: data.value?[1],
                        enums: widget.option.enums,
                        // options: widget.option.options,
                        onChanged: (value) {
                          data = FilterData(
                            id: data.id,
                            option: data.option,
                            value: [data.value?[0], value],
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  );
                  break;
                case FilterDataOptions.any:
                  optionInput = const SizedBox();
                  break;
              }
              return Flex(
                direction: Axis.vertical,
                children: [
                  InputData(
                    label: widget.option.label,
                    type: InputDataType.enums,
                    enums: FilterDataOptions.values,
                    onChanged: (value) {
                      data = FilterData(
                        id: data.id,
                        option: value ?? FilterDataOptions.any,
                        value: null,
                      );
                      if (mounted) setState(() {});
                    },
                    value: data.option,
                  ),
                  optionInput,
                ],
              );
            }),
          ),
          PopupEntry(
            child: Row(
              children: [
                TextButton(
                  onPressed: () {
                    data = widget.data;
                    if (mounted) setState(() {});
                    Navigator.of(context).pop();
                  },
                  child: const Text('cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onChange(data);
                    Navigator.of(context).pop();
                  },
                  child: const Text('apply'),
                ),
              ],
            ),
          ),
        ];
      },
      child: Chip(
        label: Text(label),
        onDeleted: widget.onDelete,
      ),
    );
  }
}

/// FilterMenu
class FilterMenu extends StatefulWidget {
  const FilterMenu({
    Key? key,
    required this.options,
    required this.data,
    required this.onChange,
  }) : super(key: key);
  final List<FilterOptions> options;
  final List<FilterData> data;
  final ValueChanged<List<FilterData>> onChange;

  @override
  State<FilterMenu> createState() => _FilterMenuState();
}

class _FilterMenuState extends State<FilterMenu> {
  late List<FilterOptions> options;
  late List<FilterData> data;

  @override
  void initState() {
    data = widget.data;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant FilterMenu oldWidget) {
    print('updated FilterMenu!!!!');
    data = widget.data;
    if (mounted) setState(() {});
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final dataIds = data.map((e) => e.id).toList();

    /// Ignore options that are included on the filters data
    options = widget.options
        .where((element) => !dataIds.contains(element.id))
        .toList();

    List<PopupMenuEntry<String>> buttons =
        List.generate(options.length, (index) {
      final option = options[index];
      return PopupMenuItem<String>(
        value: option.id,
        onTap: () {
          /// Add temporal FilterData if doesn't exist
          bool alreadyExists =
              data.where((element) => element.id == option.id).isNotEmpty;
          if (!alreadyExists) {
            // data = [...data, FilterData(id: option.id)];
            widget.onChange([...data, FilterData(id: option.id)]);
          }
        },
        child: ListTile(
          title: Text(option.label),
          trailing: const Icon(Icons.add),
        ),
      );
    });

    /// Menu List Options
    List<Widget> menuOptions = List.generate(data.length, (index) {
      final item = data[index];
      final option =
          widget.options.singleWhere((element) => element.id == item.id);
      return FilterMenuOption(
        data: item,
        option: option,
        onChange: (value) {
          final itemIndex =
              data.indexWhere((element) => element.id == option.id);
          data[itemIndex] = value;
          widget.onChange(data);
        },
        onDelete: () {
          // final itemIndex =
          // data.indexWhere((element) => element.id == option.id);
          data.removeWhere((element) => element.id == item.id);
          widget.onChange(data);
        },
      );
    });

    /// Add popUp button
    if (options.isNotEmpty) {
      menuOptions.add(PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        itemBuilder: (BuildContext context) => buttons,
      ));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: menuOptions,
    );
  }
}
