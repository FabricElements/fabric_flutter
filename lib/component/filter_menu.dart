import 'package:flutter/material.dart';

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
  }) : super(key: key);
  final FilterOptions option;
  final FilterData data;
  final ValueChanged<FilterData> onChange;

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
                  optionInput = InputData(
                    type: widget.option.type,
                    value: data.equal,
                    onChanged: (value) {
                      data = FilterData(
                        id: data.id,
                        option: data.option,
                        equal: value,
                      );
                      if (mounted) setState(() {});
                    },
                  );
                  break;
                case FilterDataOptions.notEqual:
                  optionInput = InputData(
                    type: widget.option.type,
                    value: data.notEqual,
                    onChanged: (value) {
                      data = FilterData(
                        id: data.id,
                        option: data.option,
                        notEqual: value,
                      );
                      if (mounted) setState(() {});
                    },
                  );
                  break;
                case FilterDataOptions.contains:
                  optionInput = InputData(
                    type: widget.option.type,
                    value: data.contains,
                    onChanged: (value) {
                      data = FilterData(
                        id: data.id,
                        option: data.option,
                        contains: value,
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
                        type: widget.option.type,
                        value: data.between?[0],
                        onChanged: (value) {
                          data = FilterData(
                            id: data.id,
                            option: data.option,
                            between: [value, data.between?[1]],
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                      InputData(
                        type: widget.option.type,
                        value: data.between?[0],
                        onChanged: (value) {
                          data = FilterData(
                            id: data.id,
                            option: data.option,
                            between: [data.between?[0], value],
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  );
                  break;
                case FilterDataOptions.greaterThan:
                  optionInput = InputData(
                    type: widget.option.type,
                    value: data.greaterThan,
                    onChanged: (value) {
                      data = FilterData(
                        id: data.id,
                        option: data.option,
                        greaterThan: value,
                      );
                      if (mounted) setState(() {});
                    },
                  );
                  break;
                case FilterDataOptions.lessThan:
                  optionInput = InputData(
                    type: widget.option.type,
                    value: data.lessThan,
                    onChanged: (value) {
                      data = FilterData(
                        id: data.id,
                        option: data.option,
                        lessThan: value,
                      );
                      if (mounted) setState(() {});
                    },
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
                    type: InputDataType.enums,
                    enums: FilterDataOptions.values,
                    onChanged: (value) {
                      data = FilterData(
                        id: data.id,
                        option: value,
                        any: value == FilterDataOptions.any ? true : null,
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
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 100,
          minHeight: kMinInteractiveDimension,
        ),
        padding: const EdgeInsets.all(8),
        // TODO: format and style label
        child: Text(
            '${widget.option.label} is ${widget.data.option.name} {value}'),
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
