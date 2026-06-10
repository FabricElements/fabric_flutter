import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helper/options.dart';
import '../helper/utils.dart';
import '../serialized/logs_data.dart';
import 'alert_data.dart';
import 'json_explorer_search.dart';
import 'user_chip.dart';

/// Displays a list of logs from an array of [logs]
class LogsList extends StatelessWidget {
  /// Creates a log feed that can be embedded in both scrolling pages and static
  /// detail layouts.
  const LogsList({
    super.key,
    required this.logs,
    this.actions,
    this.minimal = false,
    this.highlightColor,
    this.scrollable = false,
    this.padding = const EdgeInsets.only(
      top: 16,
      left: 16,
      right: 16,
      bottom: 8,
    ),
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  /// Provides the ordered log entries to render.
  final List<LogsData>? logs;
  /// Defines optional per-entry actions exposed through a trailing menu.
  final List<ButtonOptions>? actions;
  /// Reduces visual density for compact surfaces such as side panels.
  final bool minimal;
  /// Overrides the emphasis color used for highlighted placeholders in log text.
  final Color? highlightColor;
  /// Switches between an internal [ListView] and a fixed vertical layout.
  final bool scrollable;

  /// The amount of space using for each item.
  final EdgeInsetsGeometry padding;

  /// Main content margin space
  final EdgeInsetsGeometry margin;

  /// Builds a rich-text representation of each log entry and optional auxiliary
  /// actions.
  ///
  /// Entries can embed user mentions and structured payload previews so callers
  /// can surface audit information without building custom renderers.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    Widget container = const SizedBox(height: 0);
    if (logs == null || logs!.isEmpty) return container;
    RegExp regExp = RegExp(r'{.*?}', multiLine: true);

    /// Get item widget
    Widget getItem(LogsData item) {
      DateTime? timestamp = item.timestamp ?? DateTime.now();
      String? text = item.text?.isNotEmpty == true ? item.text : null;
      if (text == null || text.isEmpty) return container;
      List<InlineSpan> textFormatted = [];
      int? initialPosition = 0;
      TextStyle? textThemeBase = textTheme.bodyLarge?.copyWith(
        height: !minimal ? 1.7 : null,
      );
      TextStyle? textThemeColor = textThemeBase?.copyWith(
        color: highlightColor ?? textThemeBase.color ?? Colors.black,
        fontWeight: FontWeight.w600,
      );
      Iterable matches = regExp.allMatches(text);
      final timestampWidget = Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Text(
          DateFormat.yMd().add_jm().format(timestamp),
          style: textTheme.bodySmall,
        ),
      );
      if (matches.isNotEmpty) {
        for (var match in matches) {
          /// First part
          if (match.start > initialPosition) {
            textFormatted.add(
              TextSpan(
                text: (text.substring(
                  initialPosition!,
                  match.start,
                )).replaceAll('_', ' ').replaceAll('{', '').replaceAll('}', ''),
              ),
            );
            initialPosition = match.end;
          }

          /// Handle match
          String cleanMatch = match
              .group(0)
              .replaceAll('{@', '')
              .replaceAll('_', ' ')
              .replaceAll('{', '')
              .replaceAll('}', '');
          if ((match.group(0)).toString().startsWith('{@')) {
            textFormatted.add(
              WidgetSpan(
                baseline: TextBaseline.alphabetic,
                alignment: PlaceholderAlignment.middle,
                child: UserChip(
                  uid: cleanMatch,
                  minimal: minimal,
                  labelStyle: minimal ? textThemeColor : null,
                ),
              ),
            );
          } else {
            textFormatted.add(
              TextSpan(text: cleanMatch, style: textThemeColor),
            );
          }
          initialPosition = match.end;
        }

        /// Last part
        textFormatted.add(
          TextSpan(
            text: (text.substring(
              initialPosition!,
              text.length,
            )).replaceAll('_', ' ').replaceAll('{', ' ').replaceAll('}', ' '),
          ),
        );
      } else {
        textFormatted.add(TextSpan(text: text));
      }
      dynamic id = item.id ?? Utils.createCryptoRandomString(8);
      List<PopupMenuEntry<String>> buttons = [];
      Widget? actionsWidgets;
      if (actions != null) {
        for (ButtonOptions option in actions!) {
          buttons.add(
            PopupMenuItem<String>(
              onTap: option.onTap != null ? () => option.onTap!(id) : null,
              child: Text(option.label),
            ),
          );
        }
      }
      Widget? dataIcon;
      if (item.data != null) {
        dataIcon = Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: const Icon(Icons.account_tree),
            color: theme.colorScheme.onSurface,
            onPressed: () {
              alertData(
                context: context,
                widget: AlertWidget.dialog,
                type: AlertType.basic,
                scrollable: false,
                // 5 minutes in milliseconds
                duration: 300000,
                child: Container(
                  height: 600,
                  constraints: const BoxConstraints(
                    maxHeight: 600,
                    minWidth: 300,
                    minHeight: 300,
                  ),
                  child: Card(
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    child: JsonExplorerSearch(json: item.data),
                  ),
                ),
              );
            },
          ),
        );
      }
      if (buttons.isNotEmpty) {
        actionsWidgets = Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            itemBuilder: (BuildContext context) => buttons,
          ),
        );
      }

      List<Widget> vertical = [
        timestampWidget,
        Text.rich(TextSpan(children: textFormatted), style: textThemeBase),
      ];
      if (item.child != null) {
        vertical.add(
          Padding(padding: const EdgeInsets.only(top: 8), child: item.child!),
        );
      }
      List<Widget> horizontal = [
        Expanded(
          child: Flex(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            direction: Axis.vertical,
            children: vertical,
          ),
        ),
      ];
      if (dataIcon != null) horizontal.add(dataIcon);
      if (actionsWidgets != null) horizontal.add(actionsWidgets);
      return Padding(
        padding: padding,
        child: Flex(
          direction: Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: horizontal,
        ),
      );
    }

    if (scrollable) {
      return ListView.builder(
        itemCount: logs!.length,
        itemBuilder: (BuildContext context, int index) => getItem(logs![index]),
        padding: margin,
      );
    } else {
      final cellsBase = List.generate(
        logs!.length,
        (index) => getItem(logs![index]),
      );
      return Padding(
        padding: margin,
        child: Flex(direction: Axis.vertical, children: cellsBase),
      );
    }
  }
}
