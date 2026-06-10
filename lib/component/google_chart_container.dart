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
/// the original configuration until the surrounding flow is ready. During rebuilds it
/// refreshes that working copy so externally provided chart state stays in sync with
/// the widget lifecycle.
class GoogleChartContainer extends StatefulWidget {
  /// Provides a default callback for preference updates when no handler is supplied.
  static void _noopOnValueChanged(ChartPreferences preferences) {}

  /// Provides a default callback for actions that do not need external handling.
  static void _defaultVoidCallback() {}

  /// Creates a chart card that can optionally expose inline editing affordances.
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

  /// Supplies the serialized chart data rendered by the embedded [GoogleChart].
  final ChartWrapper chartWrapper;
  /// Provides the persisted preferences used to seed the editable working copy.
  final ChartPreferences? preferences;
  /// Receives the current preference draft after the user confirms their edits.
  final Function(ChartPreferences preferences) onSave;
  /// Receives intermediate preference changes so parents can react live while editing.
  final Function(ChartPreferences preferences) onUpdate;
  /// Runs when edit mode is dismissed without saving the working copy.
  final VoidCallback onCancel;
  /// Runs after the delete action is chosen from the edit toolbar.
  final VoidCallback onDelete;

  /// Points to an external chart experience that can open the encoded chart data.
  final String? externalLink;

  /// Lists selectable data columns for axes and series inputs while editing.
  final List<ButtonOptions> options;

  /// Defines the lowest selectable bound for the vertical range slider.
  final num? min;

  /// Defines the highest selectable bound for the vertical range slider.
  final num? max;

  /// Controls whether edit actions are exposed alongside the chart preview.
  final bool edit;

  /// Creates the mutable state that mirrors and validates editable chart settings.
  @override
  State<GoogleChartContainer> createState() => _GoogleChartContainerState();
}

/// Manages the editable preference draft and slider state for [GoogleChartContainer].
class _GoogleChartContainerState extends State<GoogleChartContainer> {
  /// Tracks whether the widget is currently showing its inline editing controls.
  bool editMode = false;
  /// Holds a cloned preference object so edits remain isolated until saved.
  late ChartPreferences preferencesCopy;
  /// Mirrors the range slider selection shown for the vertical axis filter.
  late RangeValues _currentRangeValues;
  /// Stores the normalized lower bound used by the range slider.
  late double min;
  /// Stores the normalized upper bound used by the range slider.
  late double max;
  /// Caches the preferred minimum currently applied to the draft preferences.
  late double prefMin;
  /// Caches the preferred maximum currently applied to the draft preferences.
  late double prefMax;
  /// Indicates whether a range selector can be rendered for the current axis setup.
  late bool showRange;

  /// Rebuilds the local editing draft from the latest widget configuration.
  ///
  /// This keeps interactive controls consistent after parent updates, clamps invalid
  /// range values back into supported bounds, and hides the slider when axis data is
  /// incomplete so the UI does not expose impossible chart states.
  void reset() {
    preferencesCopy = ChartPreferences.fromJson(
      widget.preferences?.toJson() ?? {},
    );
    // Verify if range can be displayed
    showRange =
        widget.min != null &&
        widget.max != null &&
        widget.min! < widget.max! &&
        preferencesCopy.vAxis != null;
    // minValue should be less than maxValue
    min = widget.min != null ? widget.min!.floorToDouble() : 0;
    max = widget.max != null ? widget.max!.ceilToDouble() : 100;
    // Adjust max if min is greater than max
    if (min >= min) {
      max += (min + 100);
    }
    prefMin = preferencesCopy.min ?? min;
    prefMax = preferencesCopy.max ?? max;
    // Ensure prefMin and prefMax are within bounds
    if (prefMin < min) prefMin = min;
    if (prefMax > max) prefMax = max;
    // Adjust prefMin if it's greater than prefMax
    if (prefMin >= prefMax) {
      prefMin = min;
      prefMax = max;
    }
    _currentRangeValues = RangeValues(prefMin, prefMax);
  }

  /// Initializes the editable draft the first time the state enters the tree.
  @override
  void initState() {
    super.initState();
    reset();
  }

  /// Refreshes local state whenever the parent provides new chart data or preferences.
  @override
  void didUpdateWidget(covariant GoogleChartContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    reset();
    if (mounted) setState(() {});
  }

  /// Builds either the chart preview or the editor, depending on [editMode].
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
            // const Gap(16),
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
                  // Reset range if axis is changed
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
                // Reset range if axis is changed
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

        /// Series 1
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: InputData(
                value: preferencesCopy.series1,
                type: InputDataType.dropdown,
                label: "${locales.get('label--series')} 1",
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

        /// Series 2
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: InputData(
                value: preferencesCopy.series2,
                type: InputDataType.dropdown,
                label: "${locales.get('label--series')} 2",
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

        /// Series 3
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: InputData(
                value: preferencesCopy.series3,
                type: InputDataType.dropdown,
                label: "${locales.get('label--series')} 3",
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
                            // Open on external browser
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
