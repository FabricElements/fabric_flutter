import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import '../helper/regex_helper.dart';
import '../helper/utils.dart';
import '../serialized/logs_data.dart';
import 'alert_data.dart';
import 'json_explorer_search.dart';
import 'user_chip.dart';

/// Builds a list of log entries from [logs].
///
/// Supports both fixed and scrollable layouts while formatting inline
/// placeholders into highlighted text, user chips, and optional structured data
/// previews.
class LogsList extends StatelessWidget {
  /// Creates a log list for timeline-style and detail-style surfaces.
  ///
  /// Uses [padding] for each rendered entry and [margin] around the overall
  /// collection so the same widget can adapt to dense and spacious layouts.
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

  /// Provides the ordered [LogsData] entries to render.
  final List<LogsData>? logs;

  /// Provides optional [ButtonOptions] shown for each entry in a trailing menu.
  final List<ButtonOptions>? actions;

  /// Reduces visual density for compact surfaces such as side panels.
  final bool minimal;

  /// Overrides the emphasis [Color] used for highlighted placeholders.
  final Color? highlightColor;

  /// Switches between an internal scrollable [ListView] and a fixed column.
  final bool scrollable;

  /// Provides the [EdgeInsetsGeometry] applied around each rendered entry.
  final EdgeInsetsGeometry padding;

  /// Provides the [EdgeInsetsGeometry] applied around the entire list.
  final EdgeInsetsGeometry margin;

  /// Formats each entry's timestamp as a localized date and time.
  ///
  /// Created once and shared across builds so the formatter is not rebuilt for
  /// every log row on every render.
  static final DateFormat _timestampFormat = DateFormat.yMd().add_jm();

  /// Builds the log list for the current [BuildContext].
  ///
  /// Returns an empty [SizedBox] when [logs] is `null` or empty so parents can
  /// include the widget unconditionally without adding extra visibility checks.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final locales = AppLocalizations.of(context);
    Widget container = const SizedBox(height: 0);
    if (logs == null || logs!.isEmpty) return container;

    final TextStyle? textThemeBase = textTheme.bodyLarge?.copyWith(
      height: !minimal ? 1.7 : null,
    );
    final TextStyle? textThemeColor = textThemeBase?.copyWith(
      color: highlightColor ?? textThemeBase.color ?? Colors.black,
      fontWeight: FontWeight.w600,
    );

    Widget getItem(LogsData item) {
      DateTime? timestamp = item.timestamp ?? DateTime.now();
      String? text = item.text?.isNotEmpty == true ? item.text : null;
      if (text == null || text.isEmpty) return container;
      List<InlineSpan> textFormatted = [];
      int? initialPosition = 0;
      Iterable matches = RegexHelper.placeholder.allMatches(text);
      final timestampWidget = Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Text(
          _timestampFormat.format(timestamp),
          style: textTheme.bodySmall,
        ),
      );
      if (matches.isNotEmpty) {
        for (var match in matches) {
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
      List<PopupMenuEntry<String>> buttons = [];
      Widget? actionsWidgets;
      if (actions != null) {
        // Only synthesize a fallback id when actions exist, since it is used
        // solely as the argument passed to an action's onTap. Computing it for
        // every entry on every build ran a secure RNG needlessly when the list
        // had no actions (the common case).
        dynamic id = item.id ?? Utils.createCryptoRandomString(8);
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
            tooltip: locales.get('label--view-details'),
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
            tooltip: locales.get('label--more-actions'),
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
          // Presents the timestamp and message as one composite semantics
          // node instead of separate announcements for each piece of text.
          child: MergeSemantics(
            child: Flex(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              direction: Axis.vertical,
              children: vertical,
            ),
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
