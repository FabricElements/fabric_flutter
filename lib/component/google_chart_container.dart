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

/// Container for a chart with edit mode
/// - Displays chart title and edit button
/// - In edit mode, allows changing chart preferences
/// - Calls onSave when preferences are saved
/// - Calls onUpdate when preferences are updated
/// - Calls onCancel when edit mode is cancelled
/// - Calls onDelete when chart is deleted
/// - Displays chart using GoogleChart widget
class GoogleChartContainer extends StatefulWidget {
  static void _noopOnValueChanged(ChartPreferences preferences) {}

  static void _defaultVoidCallback() {}

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

  final ChartWrapper chartWrapper;
  final ChartPreferences? preferences;
  final Function(ChartPreferences preferences) onSave;
  final Function(ChartPreferences preferences) onUpdate;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  /// External link to open the chart in a new tab
  final String? externalLink;

  /// Options for buttons
  final List<ButtonOptions> options;

  /// Options for vertical axis
  final num? min;
  final num? max;

  /// Whether to support edit mode
  final bool edit;

  @override
  State<GoogleChartContainer> createState() => _GoogleChartContainerState();
}

class _GoogleChartContainerState extends State<GoogleChartContainer> {
  bool editMode = false;
  late ChartPreferences preferencesCopy;
  late RangeValues _currentRangeValues;
  late double min;
  late double max;
  late double prefMin;
  late double prefMax;
  late bool showRange;

  /// Reset preferences to initial values
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

  @override
  void initState() {
    super.initState();
    reset();
  }

  @override
  void didUpdateWidget(covariant GoogleChartContainer oldWidget) {
    reset();
    if (mounted) setState(() {});
    super.didUpdateWidget(oldWidget);
  }

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
