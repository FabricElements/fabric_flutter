import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/enum_data.dart';
import '../helper/filter_helper.dart';
import '../helper/format_data.dart';
import '../helper/options.dart';
import '../serialized/filter_data.dart';
import 'input_data.dart';
import 'popup_entry.dart';

/// Shows the filter options for the pop-up
class FilterMenuOptionData extends StatefulWidget {
  const FilterMenuOptionData({
    super.key,
    required this.data,
    required this.onChange,
  });

  final FilterData data;
  final ValueChanged<FilterData> onChange;

  @override
  State<FilterMenuOptionData> createState() => _FilterMenuOptionDataState();
}

class _FilterMenuOptionDataState extends State<FilterMenuOptionData> {
  late FilterData edit;

  @override
  void initState() {
    edit = widget.data;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final locales = AppLocalizations.of(context);
    bool isSort =
        widget.data.operator == FilterOperator.sort || widget.data.id == 'sort';
    final enumData = EnumData(locales: locales);

    /// Define Dropdown options depending on the InputDataType
    // Ignore FilterOperator.sort
    late List<FilterOperator> dropdownOptions;
    final filterOperatorDatesOrNumbers = [
      FilterOperator.equal,
      FilterOperator.notEqual,
      FilterOperator.greaterThan,
      FilterOperator.greaterThanOrEqual,
      FilterOperator.lessThan,
      FilterOperator.lessThanOrEqual,
      FilterOperator.between,
      FilterOperator.any,
    ];
    final filterOperatorExact = [
      FilterOperator.equal,
      FilterOperator.notEqual,
      FilterOperator.any,
    ];
    switch (widget.data.type) {
      case InputDataType.email:
      case InputDataType.enums:
      case InputDataType.dropdown:
      case InputDataType.radio:
        dropdownOptions = filterOperatorExact;
        break;
      case InputDataType.date:
      case InputDataType.dateTime:
      case InputDataType.timestamp:
      case InputDataType.time:
      case InputDataType.bool:
        dropdownOptions = filterOperatorDatesOrNumbers;
        break;
      case InputDataType.double:
      case InputDataType.int:
        dropdownOptions = filterOperatorDatesOrNumbers;
        break;
      case InputDataType.text:
      case InputDataType.string:
      case InputDataType.phone:
      case InputDataType.secret:
      case InputDataType.url:
        // Using all by default
        dropdownOptions = FilterOperator.values
            .where((item) => item != FilterOperator.sort)
            .toList();
        break;
    }
    final sortOptions = FilterOrder.values
        .map((e) => ButtonOptions(
            id: e.name, value: e.name, label: enumData.localesFromEnum(e)))
        .toList();
    const space = SizedBox(height: 16, width: 16);

    /// Options
    late Widget optionInput;
    switch (edit.operator) {
      case FilterOperator.equal:
      case FilterOperator.notEqual:
      case FilterOperator.contains:
      case FilterOperator.lessThan:
      case FilterOperator.greaterThan:
      case FilterOperator.greaterThanOrEqual:
      case FilterOperator.lessThanOrEqual:
        optionInput = InputData(
          label: locales.get('label--value'),
          type: widget.data.type,
          value: edit.value,
          enums: widget.data.enums,
          options: widget.data.options,
          onChanged: (value) {
            edit.value = value;
            // Don't update the state or the position of the input will be lost
          },
          onComplete: (value) {
            edit.value = value;
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
              type: widget.data.type,
              value: edit.value?[0],
              enums: widget.data.enums,
              options: widget.data.options,
              onChanged: (value) {
                edit.value = [value, edit.value?[1]];
                // Don't update the state or the position of the input will be lost
              },
              onComplete: (value) {
                edit.value = [value, edit.value?[1]];
                if (mounted) setState(() {});
              },
            ),
            space,
            InputData(
              label: '${locales.get('label--value')} 2',
              type: widget.data.type,
              value: edit.value?[1],
              enums: widget.data.enums,
              options: widget.data.options,
              onChanged: (value) {
                edit.value = [edit.value?[0], value];
                // Don't update the state or the position of the input will be lost
              },
              onComplete: (value) {
                edit.value = [edit.value?[0], value];
                if (mounted) setState(() {});
              },
            ),
          ],
        );
        break;
      case FilterOperator.sort:
        optionInput = Flex(
          direction: Axis.vertical,
          children: [
            InputData(
              label: locales.get('label--sort-by'),
              type: InputDataType.dropdown,
              value: edit.value?[0],
              options: widget.data.options,
              onChanged: (value) {
                edit.value = [
                  value,
                  edit.value?[1],
                ];
                if (mounted) setState(() {});
              },
            ),
            space,
            InputData(
              label: locales.get('label--order'),
              type: InputDataType.dropdown,
              value: edit.value?[1],
              options: sortOptions,
              onChanged: (value) {
                edit.value = [
                  edit.value?[0],
                  value ?? FilterOrder.asc.name,
                ];
                if (mounted) setState(() {});
              },
            ),
          ],
        );
        break;
      case FilterOperator.any:
      default:
        optionInput = const SizedBox();
        break;
    }
    List<Widget> sections = [];
    if (!isSort) {
      sections.addAll([
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(widget.data.label, style: textTheme.titleMedium),
        ),
        const Divider(),
        space,
        InputData(
          floatingLabelBehavior: FloatingLabelBehavior.always,
          label: locales.get('label--operator'),
          type: InputDataType.enums,
          enums: dropdownOptions,
          onChanged: (value) {
            edit.operator = value ?? FilterOperator.any;
            edit.value = null;
            if (mounted) setState(() {});
          },
          value: edit.operator,
        ),
        space,
      ]);
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Flex(
        direction: Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...sections,
          optionInput,
          space,
          Row(
            children: [
              TextButton(
                onPressed: () {
                  // Remove the filter if the operator is null
                  if (edit.operator == null && edit.value != null) {
                    edit.value = null;
                    widget.onChange(edit);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(locales.get('label--cancel')),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  // Remove the filter if the operator is null
                  if (edit.operator == null && edit.value != null) {
                    edit.value = null;
                  }
                  widget.onChange(edit);
                },
                child: Text(locales.get('label--apply')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// FilterMenuOption
class FilterMenuOption extends StatefulWidget {
  const FilterMenuOption({
    super.key,
    required this.data,
    required this.onChange,
    required this.onDelete,
  });

  final FilterData data;
  final ValueChanged<FilterData> onChange;
  final VoidCallback onDelete;

  @override
  State<FilterMenuOption> createState() => _FilterMenuOptionState();
}

class _FilterMenuOptionState extends State<FilterMenuOption> {
  late FilterData data;

  _update() {
    data = FilterData(id: widget.data.id);
    if (mounted) setState(() {});
    data = widget.data;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    data = widget.data;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant FilterMenuOption oldWidget) {
    _update();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    _update();
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final enumData = EnumData(locales: locales);

    /// Label value
    String dataOperatorString = enumData.localesFromEnum(data.operator);
    String label = data.label;
    bool isSort = data.operator == FilterOperator.sort || data.id == 'sort';
    final sortOptions = FilterOrder.values
        .map((e) => ButtonOptions(
            id: e.name, value: e.name, label: enumData.localesFromEnum(e)))
        .toList();
    if (isSort) {
      label += ': ';
      label += data.value[0] != null
          ? data.options
              .firstWhere((element) => element.value == data.value[0],
                  orElse: () => ButtonOptions())
              .label
          : '';
      label += ' ';
      label += data.value[1] != null
          ? sortOptions
              .firstWhere((element) => element.value == data.value[1],
                  orElse: () => ButtonOptions())
              .label
          : '';
    } else if (data.operator != FilterOperator.any) {
      if (data.operator != FilterOperator.contains) {
        label += ' ${locales.get('label--is')}';
      }
      label += ' $dataOperatorString';
      label += ': ';
      try {
        switch (data.type) {
          case InputDataType.date:
          case InputDataType.dateTime:
          case InputDataType.timestamp:
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
          case InputDataType.bool:
            label += ((data.value as bool?) == true).toString().toUpperCase();
            break;
        }
      } catch (e) {
        //
      }
    }
    IconData icon = inputDataTypeIcon(data.type);
    if (isSort) {
      icon = Icons.sort;
    }
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
        return [
          PopupEntry(
            child: FilterMenuOptionData(
              data: data,
              onChange: (newValue) {
                Navigator.of(context).pop();
                FilterData copy = data;
                copy.value = newValue.value;
                copy.operator = newValue.operator;
                // Use 300 milliseconds to ensure the animation completes
                // if (mounted) setState(() {});
                Future.delayed(const Duration(milliseconds: 300)).then((time) {
                  widget.onChange(copy);
                });
              },
            ),
          ),
        ];
      },
      child: Chip(
        label: Text(label),
        avatar: Icon(icon, color: Colors.grey),
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
    super.key,
    required this.data,
    required this.onChange,
    this.icon,
    this.iconClear,
  });

  final List<FilterData> data;
  final ValueChanged<List<FilterData>> onChange;

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
  late SearchController searchController;

  _update() {
    data = [];
    if (mounted) setState(() {});
    data = widget.data;
    if (mounted) setState(() {});
  }

  void _closeSearch() {
    try {
      if (searchController.isOpen) searchController.closeView(null);
    } catch (e) {
      // Do nothing
    }
  }

  @override
  void initState() {
    searchController = SearchController();
    data = widget.data;
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _closeSearch();
    _update();
    if (mounted) setState(() {});
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant FilterMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    _closeSearch();
    _update();
  }

  @override
  void dispose() {
    _closeSearch();
    super.dispose();
  }

  void clear() {
    widget.onChange([]);
  }

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final theme = Theme.of(context);

    /// Ignore options that are included on the filters data
    List<FilterData> pendingOptions =
        data.where((element) => element.operator == null).toList();
    pendingOptions.sort((a, b) => a.label.compareTo(b.label));

    /// Active options with order
    List<FilterData> activeOptions = FilterHelper.filter(filters: data);
    activeOptions.sort((a, b) => a.index.compareTo(b.index));
    activeOptions = activeOptions.reversed.toList();

    /// Menu List Options
    List<Widget> menuOptions = List.generate(activeOptions.length, (index) {
      final item = activeOptions[index];
      FilterData selected =
          data.singleWhere((element) => element.id == item.id);
      if (selected.id == 'sort' || selected.operator == FilterOperator.sort) {
        /// Add Filter by
        selected.operator = FilterOperator.sort;
        selected.id = 'sort';
        selected.label = locales.get('label--sort-by');
        selected.options = data
            .where((element) => element.id != 'sort')
            .where((element) => element.operator != FilterOperator.sort)
            .map((e) => ButtonOptions(
                  label: e.label,
                  id: e.id,
                  value: e.id,
                ))
            .toList();
        selected.type = InputDataType.dropdown;
      }

      return FilterMenuOption(
        data: item,
        onChange: (value) {
          selected.operator = value.operator;
          selected.value = value.value;
          if (selected.onChange != null) selected.onChange!(selected);
          widget.onChange(data);
        },
        onDelete: () {
          selected.clear();
          if (selected.onChange != null) selected.onChange!(selected);
          widget.onChange(data);
        },
      );
    });

    /// Add popUp button
    if (pendingOptions.isNotEmpty) {
      menuOptions.add(SearchAnchor(
        isFullScreen: false,
        searchController: searchController,
        builder: (BuildContext context, SearchController controller) {
          return OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  theme.buttonTheme.colorScheme?.primary ?? Colors.black,
              disabledForegroundColor:
                  theme.buttonTheme.colorScheme?.primary ?? Colors.black,
              disabledMouseCursor: SystemMouseCursors.click,
            ),
            onPressed: () {
              searchController.openView();
            },
            icon: widget.icon ?? const Icon(Icons.filter_alt),
            label: Text(locales.get(
              'label--add-label',
              {'label': locales.get('label--filters')},
            )),
          );
        },
        suggestionsBuilder: (BuildContext c, SearchController controller) {
          final value = controller.text;
          List<FilterData> recommendations = pendingOptions;
          if (value.isNotEmpty) {
            recommendations = recommendations.where((element) {
              final labelMatch =
                  element.label.toLowerCase().contains(value.toLowerCase());
              final valueMatch = element.value.toString().contains(value);
              return labelMatch || valueMatch;
            }).toList();
          }
          return List<ListTile>.generate(recommendations.length, (int index) {
            final item = recommendations[index];
            FilterData selected =
                data.singleWhere((element) => element.id == item.id);
            IconData icon = inputDataTypeIcon(selected.type);
            bool isSort = selected.operator == FilterOperator.sort ||
                selected.id == 'sort';
            if (isSort) icon = Icons.sort;
            return ListTile(
              leading: Icon(icon),
              title: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              onTap: () {
                controller.closeView(null);
                int newIndex = activeOptions.length + 1;
                if (isSort) {
                  /// Add Filter by
                  selected.value = [null, null];
                  selected.operator = FilterOperator.sort;
                  selected.id = 'sort';
                  selected.label = locales.get('label--sort-by');
                  selected.options = data
                      .where((element) => element.id != 'sort')
                      .where(
                          (element) => element.operator != FilterOperator.sort)
                      .map((e) => ButtonOptions(
                            label: e.label,
                            id: e.id,
                            value: e.id,
                          ))
                      .toList();
                  selected.type = InputDataType.dropdown;
                }
                selected.index = newIndex;
                Future.delayed(const Duration(milliseconds: 50)).then((value) {
                  showDialog<void>(
                    barrierDismissible: false, // user must tap button!
                    context: context,
                    builder: (BuildContext ctx) {
                      return AlertDialog(
                        scrollable: true,
                        content: FilterMenuOptionData(
                          data: selected,
                          onChange: (newValue) {
                            Navigator.of(context).pop();
                            final merged = FilterHelper.merge(
                                filters: data, merge: [newValue]);
                            widget.onChange(merged);
                          },
                        ),
                      );
                    },
                  );
                });
                // Do not call onChange or it will trigger unwanted calls
              },
            );
          });
        },
      ));
    }
    if (activeOptions.isNotEmpty) {
      menuOptions.add(OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.buttonTheme.colorScheme?.error ?? Colors.red,
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
