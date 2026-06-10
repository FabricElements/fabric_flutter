import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import '../serialized/chart_preferences.dart';
import '../serialized/chart_wrapper.dart';
import 'edit_save_button.dart';
import 'google_chart.dart';
import 'input_data.dart';

/// Wraps a [GoogleChart] with optional editing controls for persisted chart settings.
///
/// This widget keeps a working copy of [preferences] so callers can preview edits,
/// validate axis selections, and either commit or discard changes without mutating
/// the original configuration until the surrounding flow is ready. During rebuilds
/// it refreshes that working copy so externally provided chart state stays in sync
/// with the widget lifecycle.
class GoogleChartContainer extends StatefulWidget {
  /// Provides a fallback handler for saved or live preference updates.
  ///
  /// This keeps the widget callable when a parent does not need to observe
  /// [ChartPreferences] changes.
  static void _noopOnValueChanged(ChartPreferences preferences) {}

  /// Provides a fallback handler for actions without side effects.
  ///
  /// This lets optional callbacks remain non-`null` while still doing nothing.
  static void _defaultVoidCallback() {}

  /// Creates a chart card that can optionally expose inline editing affordances.
  ///
  /// The [chartWrapper] parameter supplies the rendered dataset, while
  /// [preferences] seeds the editable draft shown when [edit] is `true`.
  const GoogleChartContainer({
    super.key,
    required this.chartWrapper,
    this.preferences,
    this.onSave = _noopOnValueChanged,
    this.onUpdate = _noopOnValueChanged,
    this.onCancel = _defaultVoidCallback,
    this.onDelete = _defaultVoidCallback,
    this.options = const [],
    this.min,
    this.max,
    this.externalLink,
    this.edit = false,
  });

  /// Stores the serialized chart data rendered by the embedded [GoogleChart].
  ///
  /// The container forwards this wrapper unchanged so the preview and external
  /// link always represent the latest chart payload.
  final ChartWrapper chartWrapper;

  /// Stores the persisted preferences used to seed the editable working copy.
  ///
  /// A `null` value leaves the draft at the model defaults until the user edits
  /// the chart.
  final ChartPreferences? preferences;

  /// Stores the callback invoked after the user confirms the current draft.
  ///
  /// The callback receives the edited [ChartPreferences] so a parent can persist
  /// the accepted settings.
  final Function(ChartPreferences preferences) onSave;

  /// Stores the callback invoked whenever the draft changes during editing.
  ///
  /// Parents can use this hook to react to intermediate [ChartPreferences]
  /// updates without waiting for a save action.
  final Function(ChartPreferences preferences) onUpdate;

  /// Stores the callback invoked when editing is dismissed without saving.
  ///
  /// This lets a parent undo surrounding UI state when the local draft is
  /// abandoned.
  final VoidCallback onCancel;

  /// Stores the callback invoked after the delete action is selected.
  ///
  /// The widget calls this after leaving edit mode so a parent can remove the
  /// associated chart configuration.
  final VoidCallback onDelete;

  /// Stores the external chart URL opened from the preview header.
  ///
  /// When present, the widget appends encoded chart data to this [String] so an
  /// external experience can render the same chart.
  final String? externalLink;

  /// Stores the selectable data columns used by editor dropdown inputs.
  ///
  /// These [ButtonOptions] values populate the axis and series selectors shown in
  /// edit mode.
  final List<ButtonOptions> options;

  /// Stores the lowest selectable bound for the vertical range slider.
  ///
  /// The widget normalizes this value before building the range selector.
  final num? min;

  /// Stores the highest selectable bound for the vertical range slider.
  ///
  /// The widget normalizes this value before building the range selector.
  final num? max;

  /// Stores whether edit actions are exposed alongside the chart preview.
  ///
  /// When `false`, the widget always renders a read-only chart card.
  final bool edit;

  /// Creates the mutable state that mirrors and validates editable chart settings.
  ///
  /// The returned [_GoogleChartContainerState] manages the local draft and range
  /// selector state.
  @override
  State<GoogleChartContainer> createState() => _GoogleChartContainerState();
}

/// Manages the editable preference draft and slider state for [GoogleChartContainer].
///
/// This state object rebuilds local values from the latest widget inputs so the
/// editor can safely reset, preview, and save chart preferences.
class _GoogleChartContainerState extends State<GoogleChartContainer> {
  /// Stores whether the widget is currently showing inline editing controls.
  ///
  /// Toggling this flag switches the card between preview and editor layouts.
  bool editMode = false;

  /// Stores a cloned preference object so edits remain isolated until saved.
  ///
  /// The state recreates this draft from [GoogleChartContainer.preferences] during
  /// resets to avoid mutating the caller's source data.
  late ChartPreferences preferencesCopy;

  /// Stores the range slider selection shown for the vertical axis filter.
  ///
  /// The current slider thumbs mirror the draft values that can be cleared or
  /// committed later.
  late RangeValues _currentRangeValues;

  /// Stores the normalized lower bound used by the range slider.
  ///
  /// This value is derived from [GoogleChartContainer.min] whenever the draft is
  /// rebuilt.
  late double min;

  /// Stores the normalized upper bound used by the range slider.
  ///
  /// This value is derived from [GoogleChartContainer.max] whenever the draft is
  /// rebuilt.
  late double max;

  /// Stores the preferred minimum currently applied to the draft preferences.
  ///
  /// The state clamps this value into the supported slider bounds before use.
  late double prefMin;

  /// Stores the preferred maximum currently applied to the draft preferences.
  ///
  /// The state clamps this value into the supported slider bounds before use.
  late double prefMax;

  /// Stores whether a range selector can be rendered for the current axis setup.
  ///
  /// The slider is hidden when chart bounds or vertical axis data are incomplete.
  late bool showRange;

  /// Rebuilds the local editing draft from the latest widget configuration.
  ///
  /// This keeps interactive controls consistent after parent updates, clamps
  /// invalid range values back into supported bounds, and hides the slider when
  /// axis data is incomplete so the UI does not expose impossible chart states.
  void reset() {
    preferencesCopy = ChartPreferences.fromJson(
      widget.preferences?.toJson() ?? {},
    );
    showRange =
        widget.min != null &&
        widget.max != null &&
        widget.min! < widget.max! &&
        preferencesCopy.vAxis != null;
    min = widget.min != null ? widget.min!.floorToDouble() : 0;
    max = widget.max != null ? widget.max!.ceilToDouble() : 100;
    if (min >= min) {
      max += (min + 100);
    }
    prefMin = preferencesCopy.min ?? min;
    prefMax = preferencesCopy.max ?? max;
    if (prefMin < min) prefMin = min;
    if (prefMax > max) prefMax = max;
    if (prefMin >= prefMax) {
      prefMin = min;
      prefMax = max;
    }
    _currentRangeValues = RangeValues(prefMin, prefMax);
  }

  /// Initializes the editable draft the first time the state enters the tree.
  ///
  /// This prepares the preview and editor before the first [build] call.
  @override
  void initState() {
    super.initState();
    reset();
  }

  /// Refreshes local state whenever the parent provides new widget inputs.
  ///
  /// The [oldWidget] value lets the framework describe the previous configuration,
  /// while this override rebuilds the local draft so edits stay aligned with the
  /// latest chart and preference data.
  @override
  void didUpdateWidget(covariant GoogleChartContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    reset();
    if (mounted) setState(() {});
  }

  /// Builds either the chart preview or the editor for the current state.
  ///
  /// The [BuildContext] provides theme and localization lookups used to render
  /// controls, labels, and the chart card layout.
  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isValid = widget.chartWrapper.isValid();
    List<Widget> sections = [];
    final editControls = EditSaveButton(
      labels: true,
      active: editMode,
      edit: () {
        editMode = !editMode;
        reset();
        if (mounted) setState(() {});
      },
      save: () {
        editMode = !editMode;
        widget.onSave(preferencesCopy);
        if (mounted) setState(() {});
      },
      cancel: () {
        editMode = !editMode;
        widget.onCancel();
        if (mounted) setState(() {});
      },
    );

    final iconDelete = Icon(Icons.delete, color: theme.colorScheme.error);

    if (widget.edit && editMode) {
      sections = [
        const Gap(8),
        Row(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.delete),
              onPressed: () {
                editMode = !editMode;
                widget.onCancel();
                if (mounted) setState(() {});
                widget.onDelete();
              },
              label: Text(locales.get('label--delete')),
            ),
            const Spacer(),
            editControls,
          ],
        ),
        const Divider(),
        const Gap(16),
        InputData(
          value: preferencesCopy.name,
          type: InputDataType.string,
          label: locales.get('label--name'),
          onChanged: (value) {
            preferencesCopy.name = value;
            widget.onUpdate(preferencesCopy);
          },
        ),
        const Gap(16),
        InputData(
          value: preferencesCopy.type,
          type: InputDataType.enums,
          enums: ChartType.values,
          label: locales.get('label--type'),
          onChanged: (value) {
            preferencesCopy.type = value;
            widget.onUpdate(preferencesCopy);
          },
        ),
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: InputData(
                value: preferencesCopy.hAxis,
                type: InputDataType.dropdown,
                label: locales.get('label--horizontal-axis'),
                options: widget.options,
                onChanged: (value) {
                  preferencesCopy.hAxis = value;
                  widget.onUpdate(preferencesCopy);
                },
              ),
            ),
            IconButton(
              icon: iconDelete,
              onPressed: () {
                preferencesCopy.hAxis = null;
                widget.onUpdate(preferencesCopy);
              },
            ),
          ],
        ),
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: InputData(
                value: preferencesCopy.vAxis,
                type: InputDataType.dropdown,
                label: locales.get('label--vertical-axis'),
                options: widget.options,
                onChanged: (value) {
                  preferencesCopy.vAxis = value;
                  preferencesCopy.min = null;
                  preferencesCopy.max = null;
                  widget.onUpdate(preferencesCopy);
                },
              ),
            ),
            IconButton(
              icon: iconDelete,
              onPressed: () {
                preferencesCopy.vAxis = null;
                preferencesCopy.min = null;
                preferencesCopy.max = null;
                widget.onUpdate(preferencesCopy);
              },
            ),
          ],
        ),
        const Gap(16),
        if (showRange)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              theme
                                  .inputDecorationTheme
                                  .enabledBorder
                                  ?.borderSide
                                  .color ??
                              theme.dividerColor,
                          width:
                              theme
                                  .inputDecorationTheme
                                  .enabledBorder
                                  ?.borderSide
                                  .width ??
                              1.0,
                          style:
                              theme
                                  .inputDecorationTheme
                                  .enabledBorder
                                  ?.borderSide
                                  .style ??
                              BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: RangeSlider(
                        values: _currentRangeValues,
                        max: max,
                        min: min,
                        divisions: (max / 20).floor(),
                        labels: RangeLabels(
                          NumberFormat().format(
                            _currentRangeValues.start.floor(),
                          ),
                          NumberFormat().format(_currentRangeValues.end.ceil()),
                        ),
                        onChanged: (RangeValues values) {
                          preferencesCopy.min = values.start.floorToDouble();
                          preferencesCopy.max = values.end.ceilToDouble();
                          _currentRangeValues = RangeValues(
                            preferencesCopy.min!,
                            preferencesCopy.max!,
                          );
                          if (mounted) setState(() {});
                        },
                        onChangeEnd: (RangeValues values) {
                          preferencesCopy.min = values.start.floorToDouble();
                          preferencesCopy.max = values.end.ceilToDouble();
                          _currentRangeValues = RangeValues(
                            preferencesCopy.min!,
                            preferencesCopy.max!,
                          );
                          widget.onUpdate(preferencesCopy);
                        },
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 12,
                      child: Container(
                        color: theme.colorScheme.surface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          '${locales.get('label--range')} (${NumberFormat().format(_currentRangeValues.start.floor())} - ${NumberFormat().format(_currentRangeValues.end.ceil())})',
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: iconDelete,
                onPressed: () {
                  preferencesCopy.min = null;
                  preferencesCopy.max = null;
                  _currentRangeValues = RangeValues(min, max);
                  widget.onUpdate(preferencesCopy);
                },
              ),
            ],
          ),
        const Gap(16),
        const Divider(),
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: InputData(
                value: preferencesCopy.series1,
                type: InputDataType.dropdown,
                label: '${locales.get('label--series')} 1',
                options: widget.options,
                onChanged: (value) {
                  preferencesCopy.series1 = value;
                  widget.onUpdate(preferencesCopy);
                },
              ),
            ),
            IconButton(
              icon: iconDelete,
              onPressed: () {
                preferencesCopy.series1 = null;
                widget.onUpdate(preferencesCopy);
              },
            ),
          ],
        ),
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: InputData(
                value: preferencesCopy.series2,
                type: InputDataType.dropdown,
                label: '${locales.get('label--series')} 2',
                options: widget.options,
                onChanged: (value) {
                  preferencesCopy.series2 = value;
                  widget.onUpdate(preferencesCopy);
                },
              ),
            ),
            IconButton(
              icon: iconDelete,
              onPressed: () {
                preferencesCopy.series2 = null;
                widget.onUpdate(preferencesCopy);
              },
            ),
          ],
        ),
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: InputData(
                value: preferencesCopy.series3,
                type: InputDataType.dropdown,
                label: '${locales.get('label--series')} 3',
                options: widget.options,
                onChanged: (value) {
                  preferencesCopy.series3 = value;
                  widget.onUpdate(preferencesCopy);
                },
              ),
            ),
            IconButton(
              icon: iconDelete,
              onPressed: () {
                preferencesCopy.series3 = null;
                widget.onUpdate(preferencesCopy);
              },
            ),
          ],
        ),
        const Gap(16),
      ];
    } else {
      final chart = ClipRect(child: GoogleChart(data: widget.chartWrapper));
      sections = [
        if (widget.preferences?.name != null ||
            widget.externalLink != null ||
            widget.edit)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: widget.preferences?.name != null
                ? Text(widget.preferences!.name!)
                : null,
            leading: widget.externalLink != null
                ? IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: isValid
                        ? () async {
                            final url =
                                '${widget.externalLink}?data=${widget.chartWrapper.encode()}';
                            await launchUrl(Uri.parse(url));
                          }
                        : null,
                  )
                : null,
            trailing: widget.edit ? editControls : null,
          ),
        const Gap(16),
        AspectRatio(aspectRatio: 1.1, child: chart),
      ];
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Flex(
          direction: Axis.vertical,
          mainAxisSize: MainAxisSize.min,
          children: sections,
        ),
      ),
    );
  }
}
