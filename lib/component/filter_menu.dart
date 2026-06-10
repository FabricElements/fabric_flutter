import 'package:flutter/foundation.dart';
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

/// Shows editable controls for a single filter inside a popup surface.
///
/// The widget works on a temporary [FilterData] copy so callers can cancel the
/// popup without mutating the original filter until the user explicitly applies
/// the change.
class FilterMenuOptionData extends StatefulWidget {
  /// Creates the popup editor for an individual filter.
  ///
  /// The [data] argument provides the source filter definition, and [onChange]
  /// receives the committed copy after the user applies the update.
  const FilterMenuOptionData({
    super.key,
    required this.data,
    required this.onChange,
  });

  /// Stores the source filter being edited in the popup.
  ///
  /// The state object clones this [FilterData] so temporary field edits stay
  /// local until the user confirms the change.
  final FilterData data;

  /// Receives the committed filter after the user taps Apply.
  ///
  /// The callback returns the edited [FilterData] so the parent can merge the
  /// result into its canonical filter collection.
  final ValueChanged<FilterData> onChange;

  /// Creates the state that owns the temporary editable filter copy.
  ///
  /// The returned [_FilterMenuOptionDataState] keeps draft values isolated from
  /// the parent widget while the popup is open.
  @override
  State<FilterMenuOptionData> createState() => _FilterMenuOptionDataState();
}

/// Holds draft filter values while the popup remains open.
///
/// The state object keeps a defensive copy of [FilterMenuOptionData.data] so
/// users can abandon partial edits without mutating the original filter.
class _FilterMenuOptionDataState extends State<FilterMenuOptionData> {
  /// Stores the defensive copy used during popup editing.
  ///
  /// The field mirrors [FilterMenuOptionData.data] at initialization time and
  /// then absorbs in-progress edits until the popup is applied.
  late FilterData edit;

  /// Clones the incoming filter before any field widgets start mutating it.
  ///
  /// The copy prevents direct writes to [FilterMenuOptionData.data] while the
  /// popup remains dismissible.
  @override
  void initState() {
    super.initState();
    edit = FilterData.fromJson(widget.data.toJson());
  }

  /// Reads clipboard text and converts it into valid values for the current filter type.
  ///
  /// This supports bulk entry for operators such as [FilterOperator.whereIn],
  /// while ignoring empty or invalid items so pasted spreadsheet data does not
  /// corrupt the in-progress filter state.
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

  /// Builds the operator-specific editor shown inside the filter popup.
  ///
  /// The widget tree adapts to the active [FilterOperator] so each filter type
  /// presents the correct input control for editing within the current
  /// [BuildContext].
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

/// Renders an active filter as a chip that can be reopened for editing.
///
/// Each chip summarizes the current operator and value so users can understand
/// the active query at a glance before changing or removing it.
class FilterMenuOption extends StatefulWidget {
  /// Creates a chip for one active filter entry.
  ///
  /// The [data] argument defines the active filter, [onChange] applies edits
  /// from the popup, and [onDelete] removes the filter entirely.
  const FilterMenuOption({
    super.key,
    required this.data,
    required this.onChange,
    required this.onDelete,
  });

  /// Stores the active filter represented by this chip.
  ///
  /// The value supplies the current label, operator, and selection shown to the
  /// user before they reopen the editor.
  final FilterData data;

  /// Receives an updated filter after the popup editor commits a change.
  ///
  /// The callback lets the parent replace the active [FilterData] without
  /// coupling this chip to collection management.
  final ValueChanged<FilterData> onChange;

  /// Removes the filter from the parent collection.
  ///
  /// The callback is wired to the chip delete affordance so the parent can
  /// clear the matching [FilterData] entry.
  final VoidCallback onDelete;

  /// Creates the state that keeps a local snapshot for rendering transitions.
  ///
  /// The returned [_FilterMenuOptionState] derives display text and popup state
  /// from the latest [FilterData].
  @override
  State<FilterMenuOption> createState() => _FilterMenuOptionState();
}

/// Formats one filter into a human-readable chip label and edit menu.
///
/// The state object maintains a local [FilterData] snapshot so chip rendering
/// stays synchronized with parent updates and inherited localization changes.
class _FilterMenuOptionState extends State<FilterMenuOption> {
  /// Stores the filter snapshot currently shown by the chip.
  ///
  /// The value is refreshed from [FilterMenuOption.data] whenever the widget or
  /// its dependencies change.
  late FilterData data;

  /// Refreshes the local snapshot when inherited or widget state changes.
  ///
  /// The temporary reset forces dependent chip content to rebuild before the
  /// latest [FilterData] is reassigned.
  void _update() {
    data = FilterData(id: widget.data.id);
    if (mounted) setState(() {});
    data = widget.data;
    if (mounted) setState(() {});
  }

  /// Seeds the local filter snapshot during the first lifecycle pass.
  ///
  /// The initial value mirrors [FilterMenuOption.data] before any rebuilds or
  /// popup edits occur.
  @override
  void initState() {
    super.initState();
    data = widget.data;
  }

  /// Re-synchronizes the displayed chip label when the parent provides a new filter.
  ///
  /// The method refreshes derived display state after Flutter swaps in a new
  /// [FilterMenuOption] configuration.
  @override
  void didUpdateWidget(covariant FilterMenuOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  /// Rebuilds derived label data after inherited dependencies change.
  ///
  /// This keeps localized filter labels current when the surrounding
  /// [BuildContext] updates.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  /// Builds the summary chip and popup editor for the active filter.
  ///
  /// The returned widget shows the current filter state, opens the editor on
  /// demand, and delegates change handling through [FilterMenuOption.onChange].
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

/// Displays active filters and exposes UI for adding, editing, and clearing them.
///
/// The menu separates inactive filter definitions from active filter values so
/// a parent can keep one canonical list of [FilterData] objects while this
/// widget manages the popup and search interactions needed to edit them.
class FilterMenu extends StatefulWidget {
  /// Creates a filter menu for the provided filter definitions.
  ///
  /// The [data] collection supplies both available and active filters, while
  /// [onChange] receives merged updates after the user edits the menu.
  const FilterMenu({
    super.key,
    required this.data,
    required this.onChange,
    this.icon,
    this.iconClear,
  });

  /// Stores the full set of available and active filter definitions.
  ///
  /// The list includes inactive filter templates alongside any filters that are
  /// currently applied to the surrounding result set.
  final List<FilterData> data;

  /// Receives the updated filter collection after any user action.
  ///
  /// The callback returns the canonical [List] of [FilterData] entries so the
  /// parent can persist ordering, values, and clear actions.
  final ValueChanged<List<FilterData>> onChange;

  /// Stores the optional icon used by the add-filter trigger.
  ///
  /// When supplied, the add control behaves like an icon-styled button while
  /// preserving the same search-driven filter selection flow.
  final Widget? icon;

  /// Stores the optional icon used by the clear-filters action.
  ///
  /// The widget replaces the default clear icon without changing the action
  /// that resets every active [FilterData].
  final Widget? iconClear;

  /// Creates the state that tracks the active filter list and search surface.
  ///
  /// The returned [_FilterMenuState] manages the searchable add-filter view and
  /// the active filter chip collection.
  @override
  State<FilterMenu> createState() => _FilterMenuState();
}

/// Manages the searchable add-filter menu and active filter chip list.
///
/// The state object mirrors [FilterMenu.data], coordinates a [SearchController],
/// and translates popup edits into parent-facing filter updates.
class _FilterMenuState extends State<FilterMenu> {
  /// Stores the current filter collection mirrored from [FilterMenu.data].
  ///
  /// The list is refreshed whenever the widget configuration changes so search
  /// results and active chips stay in sync.
  late List<FilterData> data;

  /// Controls the Material search view used to add new filters.
  ///
  /// The [SearchController] opens, closes, and clears the add-filter search
  /// surface displayed by this widget.
  late SearchController searchController;

  /// Refreshes local state from the latest widget configuration.
  ///
  /// The temporary reset forces dependent widgets to rebuild before the newest
  /// [FilterMenu.data] list is reassigned.
  void _update() {
    data = [];
    if (mounted) setState(() {});
    data = widget.data;
    if (mounted) setState(() {});
  }

  /// Closes the search UI and clears any partial query text.
  ///
  /// The method safely resets the [SearchController] even when the search view
  /// has already been dismissed elsewhere in the widget tree.
  void _closeSearch() {
    try {
      searchController.clear();
      if (searchController.isOpen) searchController.closeView(null);
    } catch (e) {
      // Do nothing
    }
  }

  /// Initializes the search controller and local filter snapshot.
  ///
  /// The initial state mirrors [FilterMenu.data] and prepares the controller
  /// before the first search interaction occurs.
  @override
  void initState() {
    super.initState();
    searchController = SearchController();
    data = widget.data;
  }

  /// Re-synchronizes local filter state when inherited values change.
  ///
  /// This keeps localized labels and other [BuildContext]-driven state aligned
  /// with the latest inherited widgets.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  /// Re-synchronizes local filter state when the parent rebuilds with new data.
  ///
  /// The method refreshes the local mirror after Flutter swaps in a new
  /// [FilterMenu] configuration.
  @override
  void didUpdateWidget(covariant FilterMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  /// Disposes the search controller and closes the search view during teardown.
  ///
  /// The cleanup guards against stale search overlays before the state object is
  /// removed from the widget tree.
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

  /// Removes every active filter and reports the cleared list to the parent.
  ///
  /// Calling [FilterMenu.onChange] with an empty collection lets the parent
  /// reset its canonical filter state in one step.
  void clear() {
    widget.onChange([]);
  }

  /// Builds active filter chips plus controls for adding or clearing filters.
  ///
  /// The layout adapts the chip list and search entry points to the current
  /// [BuildContext] while preserving filter ordering and sort behavior.
  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;
    // The max size for an iPad screen is 1366, so we consider medium screen between 600 and 1366
    final isMediumScreen = width >= 600 && width < 1366;

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
          isFullScreen: kIsWeb == true ? true : null,
          // isFullScreen:
          //     kIsWeb ||
          //     isSmallScreen ||
          //     (isMediumScreen && pendingOptions.length >= 10),
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
