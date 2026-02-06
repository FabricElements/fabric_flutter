import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

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
    super.initState();
    edit = FilterData.fromJson(widget.data.toJson());
  }

  /// Get the value from the clipboard, validating the type, and return a valid list
  Future<List> pasteValues() async {
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData == null) return [];
    final clipboardText = clipboardData.text ?? '';
    // values can come on comma-separated values, new lines, tabs, or from a table
    final valuesFromClipboard = clipboardText
        .split(RegExp(r'[\n\t,]'))
        .map((e) => e.trim())
        .toList();
    // Validate values depending on the type
    List<dynamic> newValues = [];
    for (var value in valuesFromClipboard) {
      try {
        if (value.isEmpty) continue;
        dynamic newValue;
        switch (edit.type) {
          case InputDataType.email:
          case InputDataType.currency:
          case InputDataType.percent:
          case InputDataType.text:
          case InputDataType.string:
          case InputDataType.phone:
          case InputDataType.url:
          case InputDataType.secret:
            newValue = value;
            break;
          case InputDataType.int:
            final base = int.tryParse(value);
            if (base != null && !base.isNaN && !base.isInfinite) {
              newValue = base;
            }
            break;
          case InputDataType.double:
            final base = double.tryParse(value);
            if (base != null && !base.isNaN && !base.isInfinite) {
              newValue = base;
            }
            break;
          case InputDataType.date:
          case InputDataType.dateTime:
          case InputDataType.timestamp:
            newValue = DateTime.tryParse(value);
            break;
          case InputDataType.time:
            final base = DateTime.tryParse(value);
            if (base != null) {
              newValue = TimeOfDay.fromDateTime(base);
            }
            break;
          case InputDataType.enums:
            newValue = EnumData.findFromString(enums: edit.enums, value: value);
            break;
          case InputDataType.bool:
            newValue = bool.tryParse(value.toString().toLowerCase());
            break;
          case InputDataType.dropdown:
          case InputDataType.radio:
            final option = edit.options.firstWhere(
              (element) => element.value == value,
            );
            newValue = option.value;
            break;
        }
        if (newValue != null && newValue.toString().trim().isNotEmpty) {
          newValues.add(newValue);
        }
      } catch (e) {
        // Do nothing
      }
    }
    return newValues;
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
    List<FilterOperator> filterOperatorDatesOrNumbers = [
      FilterOperator.equal,
      FilterOperator.notEqual,
      FilterOperator.greaterThan,
      FilterOperator.greaterThanOrEqual,
      FilterOperator.lessThan,
      FilterOperator.lessThanOrEqual,
      FilterOperator.between,
      FilterOperator.any,
      FilterOperator.whereIn,
    ];
    filterOperatorDatesOrNumbers.sort((a, b) => a.name.compareTo(b.name));
    List<FilterOperator> filterOperatorExact = [
      FilterOperator.equal,
      FilterOperator.notEqual,
      FilterOperator.any,
      FilterOperator.whereIn,
    ];
    filterOperatorExact.sort((a, b) => a.name.compareTo(b.name));

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
      case InputDataType.int:
      case InputDataType.double:
      case InputDataType.currency:
      case InputDataType.percent:
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
        .map(
          (e) => ButtonOptions(
            id: e.name,
            value: e.name,
            label: enumData.localesFromEnum(e),
          ),
        )
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
          autofillHints: const [],
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
      case FilterOperator.whereIn:
        List<dynamic> values = edit.value ?? [];
        if (edit.operator == FilterOperator.between) {
          values = List.generate(2, (index) {
            if (values.length > index) {
              return values[index];
            }
            return null;
          });
        }
        if (edit.operator == FilterOperator.whereIn) {
          values = values.isNotEmpty ? values : [];
        }
        bool isMultiple = edit.operator == FilterOperator.whereIn;
        optionInput = Flex(
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (values.isNotEmpty)
              ...List.generate(values.length, (index) {
                final removeButton = IconButton(
                  color: theme.colorScheme.error,
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    values.removeAt(index);
                    edit.value = values;
                    if (mounted) setState(() {});
                  },
                );
                Widget button = InputData(
                  label: '${locales.get('label--value')} ${index + 1}',
                  type: widget.data.type,
                  value: values[index],
                  enums: widget.data.enums,
                  options: widget.data.options,
                  onChanged: (value) {
                    // Update the value at the index
                    values[index] = value;
                    edit.value = values;
                    // Don't update the state or the position of the input will be lost
                  },
                  onComplete: (value) {
                    // Update the value at the index
                    values[index] = value;
                    edit.value = values;
                    if (mounted) setState(() {});
                  },
                );
                if (isMultiple) {
                  button = Row(
                    children: [
                      Expanded(child: button),
                      removeButton,
                    ],
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: button,
                );
              }),
            if (isMultiple)
              OutlinedButton.icon(
                onPressed: () {
                  values.add(null);
                  edit.value = values;
                  if (mounted) setState(() {});
                },
                onLongPress: () async {
                  // Paste and Add values without duplicates
                  final newValues = await pasteValues();
                  if (newValues.isEmpty) return;
                  values = <dynamic>{...values, ...newValues}.toList();
                  edit.value = values;
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.add),
                label: Text(
                  locales.get('label--add-label', {
                    'label': locales.get('label--value'),
                  }),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.buttonTheme.colorScheme?.primary,
                  iconColor: theme.buttonTheme.colorScheme?.primary,
                  side: BorderSide(
                    color:
                        theme.buttonTheme.colorScheme?.primary ??
                        theme.colorScheme.primary,
                  ),
                ),
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
                edit.value = [value, edit.value?[1]];
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
                edit.value = [edit.value?[0], value ?? FilterOrder.asc.name];
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
    return PointerInterceptor(
      child: Padding(
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

  void _update() {
    data = FilterData(id: widget.data.id);
    if (mounted) setState(() {});
    data = widget.data;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    data = widget.data;
  }

  @override
  void didUpdateWidget(covariant FilterMenuOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final enumData = EnumData(locales: locales);
    final theme = Theme.of(context);

    /// Label value
    String dataOperatorString = enumData.localesFromEnum(data.operator);
    String label = data.label;
    bool isSort = data.operator == FilterOperator.sort || data.id == 'sort';
    final sortOptions = FilterOrder.values
        .map(
          (e) => ButtonOptions(
            id: e.name,
            value: e.name,
            label: enumData.localesFromEnum(e),
          ),
        )
        .toList();
    if (isSort) {
      label += ': ';
      label += data.value != null && data.value[0] != null
          ? data.options
                .firstWhere(
                  (element) => element.value == data.value[0],
                  orElse: () => ButtonOptions(),
                )
                .label
          : '';
      label += ' ';
      label += data.value != null && data.value[1] != null
          ? sortOptions
                .firstWhere(
                  (element) => element.value == data.value[1],
                  orElse: () => ButtonOptions(),
                )
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
            switch (data.operator) {
              case FilterOperator.between:
                label += FormatData.formatDateShort().format(data.value[0]);
                label += ' ${locales.get('label--and')} ';
                label += FormatData.formatDateShort().format(data.value[1]);
                break;
              case FilterOperator.whereIn:
                label += data.value
                    .map((e) => FormatData.formatDateShort().format(e))
                    .join(', ');
                break;
              default:
                label += FormatData.formatDateShort().format(data.value);
                break;
            }
            break;
          case InputDataType.time:
            switch (data.operator) {
              case FilterOperator.between:
                label += data.value[0].format(context);
                label += ' ${locales.get('label--and')} ';
                label += data.value[1].format(context);
                break;
              case FilterOperator.whereIn:
                label += (data.value as List<dynamic>)
                    .map((e) => e.format())
                    .join(', ');
                break;
              default:
                label += data.value.format(context);
                break;
            }
            break;
          case InputDataType.email:
          case InputDataType.int:
          case InputDataType.double:
          case InputDataType.currency:
          case InputDataType.percent:
          case InputDataType.text:
          case InputDataType.string:
          case InputDataType.phone:
          case InputDataType.url:
            switch (data.operator) {
              case FilterOperator.between:
                label += data.value[0].toString();
                label += ' ${locales.get('label--and')} ';
                label += data.value[1].toString();
                break;
              case FilterOperator.whereIn:
                label += (data.value as List<dynamic>)
                    .map((e) => e.toString())
                    .join(', ');
                break;
              default:
                label += data.value.toString();
                break;
            }
            break;
          case InputDataType.enums:
            switch (data.operator) {
              case FilterOperator.whereIn:
                label += (data.value as List<dynamic>)
                    .map((e) => enumData.localesFromEnum(e))
                    .join(', ');
                break;
              default:
                label += enumData.localesFromEnum(data.value);
                break;
            }
            break;
          case InputDataType.dropdown:
          case InputDataType.radio:
            label += data.options
                .firstWhere(
                  (element) => element.value == data.value,
                  orElse: () => ButtonOptions(),
                )
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
    return PointerInterceptor(
      child: PopupMenuButton(
        tooltip: locales.get('label--edit-label', {'label': data.label}),
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
                  Future.delayed(const Duration(milliseconds: 300)).then((
                    time,
                  ) {
                    widget.onChange(copy);
                  });
                },
              ),
            ),
          ];
        },
        child: Chip(
          mouseCursor: SystemMouseCursors.click,
          label: Text(label),
          avatar: Icon(icon, color: theme.colorScheme.onSurface),
          onDeleted: widget.onDelete,
          deleteButtonTooltipMessage: locales.get('label--remove-label', {
            'label': locales.get('label--filter'),
          }),
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

  void _update() {
    data = [];
    if (mounted) setState(() {});
    data = widget.data;
    if (mounted) setState(() {});
  }

  void _closeSearch() {
    try {
      searchController.clear();
      if (searchController.isOpen) searchController.closeView(null);
    } catch (e) {
      // Do nothing
    }
  }

  @override
  void initState() {
    super.initState();
    searchController = SearchController();
    data = widget.data;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(covariant FilterMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void dispose() {
    _closeSearch();
    try {
      searchController.dispose();
    } catch (e) {
      // Do nothing
    }
    super.dispose();
  }

  void clear() {
    widget.onChange([]);
  }

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;

    /// Ignore options that are included on the filters data
    List<FilterData> pendingOptions = data
        .where((element) => element.operator == null)
        .toList();
    pendingOptions.sort((a, b) => a.label.compareTo(b.label));

    /// Active options with order
    List<FilterData> activeOptions = FilterHelper.filter(filters: data);
    activeOptions.sort((a, b) => a.index.compareTo(b.index));
    activeOptions = activeOptions.reversed.toList();

    /// get the sort option
    final sortOptionFromData = activeOptions.firstWhere(
      (element) => element.operator == FilterOperator.sort,
      orElse: () =>
          FilterData(id: 'sort', operator: FilterOperator.sort, index: 1),
    );
    final optionsIgnoringSort = data.where(
      (element) =>
          element.id != 'sort' && element.operator != FilterOperator.sort,
    );
    final sortOptions = optionsIgnoringSort
        .map((e) => ButtonOptions(label: e.label, id: e.id, value: e.id))
        .toList();
    final sortOption = FilterData(
      id: 'sort',
      operator: FilterOperator.sort,
      label: locales.get('label--sort-by'),
      value: sortOptionFromData.value ?? [null, null],
      index: 1,
      type: InputDataType.dropdown,
      options: sortOptions,
    );

    /// Check if the sort option is already in the list
    bool hasSort = activeOptions.any((element) => element.id == 'sort');
    if (hasSort) {
      /// Remove sort from list
      activeOptions.removeWhere(
        (element) =>
            element.id == 'sort' || element.operator == FilterOperator.sort,
      );

      /// Add [sortOption] to the beginning of the array
      activeOptions.insert(0, sortOption);
    }

    /// Update index
    activeOptions.map((e) => e.index = activeOptions.indexOf(e));

    /// Menu List Options
    List<Widget> menuOptions = List.generate(activeOptions.length, (index) {
      final item = activeOptions[index];
      FilterData selected = data.singleWhere(
        (element) => element.id == item.id,
      );
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
      menuOptions.add(
        SearchAnchor(
          isFullScreen: isSmallScreen || pendingOptions.length > 10,
          searchController: searchController,
          builder: (BuildContext context, SearchController controller) {
            return PointerInterceptor(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      theme.buttonTheme.colorScheme?.primary ??
                      theme.colorScheme.primary,
                  disabledForegroundColor:
                      theme.buttonTheme.colorScheme?.primary ??
                      theme.colorScheme.primary,
                  side: BorderSide(
                    color:
                        theme.buttonTheme.colorScheme?.primary ??
                        theme.colorScheme.primary,
                  ),
                  disabledMouseCursor: SystemMouseCursors.click,
                  iconColor:
                      theme.buttonTheme.colorScheme?.primary ??
                      theme.colorScheme.primary,
                ),
                onPressed: () {
                  searchController.openView();
                },
                icon: widget.icon ?? const Icon(Icons.filter_alt),
                label: Text(
                  locales.get('label--add-label', {
                    'label': locales.get('label--filters'),
                  }),
                ),
              ),
            );
          },
          suggestionsBuilder: (BuildContext c, SearchController controller) {
            final value = controller.text;
            List<FilterData> recommendations = pendingOptions;
            if (value.isNotEmpty) {
              recommendations = recommendations.where((element) {
                final labelMatch = element.label.toLowerCase().contains(
                  value.toLowerCase(),
                );
                final valueMatch = element.value.toString().contains(value);
                return labelMatch || valueMatch;
              }).toList();
            }
            return List.generate(recommendations.length, (int index) {
              final item = recommendations[index];
              FilterData selected = data.singleWhere(
                (element) => element.id == item.id,
              );
              IconData icon = inputDataTypeIcon(selected.type);
              bool isSort =
                  selected.operator == FilterOperator.sort ||
                  selected.id == 'sort';
              if (isSort) icon = Icons.sort;
              return PointerInterceptor(
                child: ListTile(
                  leading: Icon(icon),
                  title: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  onTap: () {
                    int newIndex = activeOptions.length + 1;
                    selected.index = newIndex;
                    if (isSort) {
                      /// Add Sort by
                      selected.value = [null, null];
                      selected.operator = FilterOperator.sort;
                      selected.id = 'sort';
                      selected.label = locales.get('label--sort-by');
                      selected.options = sortOptions;
                      selected.type = InputDataType.dropdown;
                      // Update index
                      selected.index = 1;
                    }
                    _closeSearch();
                    // Do not call onChange or it will trigger unwanted calls
                    showDialog<void>(
                      barrierDismissible: false, // user must tap button!
                      context: c,
                      builder: (BuildContext ctx) {
                        return PointerInterceptor(
                          child: AlertDialog(
                            key: ValueKey(
                              'filter-menu-option-data-pop-up-${item.id}',
                            ),
                            scrollable: true,
                            content: FilterMenuOptionData(
                              key: ValueKey(
                                'filter-menu-option-data-${item.id}',
                              ),
                              data: selected,
                              onChange: (newValue) {
                                Navigator.of(ctx).pop();
                                final merged = FilterHelper.merge(
                                  filters: data,
                                  merge: [newValue],
                                );
                                widget.onChange(merged);
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            });
          },
        ),
      );
    }
    if (activeOptions.isNotEmpty) {
      menuOptions.add(
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.buttonTheme.colorScheme?.error ?? Colors.red,
            side: BorderSide(
              color: theme.buttonTheme.colorScheme?.error ?? Colors.red,
            ),
            iconColor: theme.buttonTheme.colorScheme?.error ?? Colors.red,
          ),
          onPressed: clear,
          icon: widget.iconClear ?? const Icon(Icons.clear),
          label: Text(
            locales.get('label--clear-label', {
              'label': locales.get('label--filters'),
            }),
          ),
        ),
      );
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
