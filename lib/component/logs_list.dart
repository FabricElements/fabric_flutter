import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helper/options.dart';
import 'user_chip.dart';

/// [LogsList] displays a list of logs from an array of [data]
///
/// Example:
/// ----------------------------------------------------
/// LogsList(
///   actions: [
///     ButtonOptions(
///       label: "Load version",
///       onTap: (dynamic id) {
///         print("id: $id");
///       },
///     ),
///   ],
///   data: [
///     {
///       'text': '{Donec} nec {justo} eget felis facilisis fermentum.',
///       'id': 'hello',
///       'timestamp': "2021-11-09T09:25:27",
///     },
///     {
///       'text':
///           '{@Vcr3IZKdvqepEj51vjM8xqLxzfq1} Vestibulum commodo {@VnCYNfYzlVQc3fCAJH2LyNv9vGj2} demo {porttitor} felis.',
///       'id': 'demo',
///       'timestamp': "2021-11-09T20:23:27"
///     },
///   ],
/// ),
class LogsList extends StatelessWidget {
  const LogsList({
    Key? key,
    required this.data,
    this.actions,
    this.minimal = false,
    this.highlightColor,
    this.scrollable = false,
    this.padding =
        const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  }) : super(key: key);
  final List<Map<String, dynamic>>? data;
  final List<ButtonOptions>? actions;
  final bool minimal;
  final Color? highlightColor;
  final bool scrollable;

  /// The amount of space using for each item.
  final EdgeInsetsGeometry padding;

  /// Main content margin space
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    Widget container = const SizedBox(height: 0);
    if (data == null || data!.isEmpty) return container;
    RegExp regExp = RegExp(r'{.*?}', multiLine: true);
    Widget getItem(Map<String, dynamic> item) {
      DateTime? timestamp =
          item.containsKey('timestamp') && item['timestamp'].isNotEmpty
              ? DateTime.tryParse(item['timestamp'].toString())?.toUtc()
              : null;
      String? text = item.containsKey('text') && item['text'].isNotEmpty
          ? item['text']
          : null;
      if (text == null || text.isEmpty) return container;
      List<InlineSpan> textFormatted = [];
      int? initialPosition = 0;
      TextStyle? textThemeBase =
          textTheme.bodyText1?.copyWith(height: !minimal ? 1.7 : null);
      TextStyle? textThemeColor = textThemeBase?.copyWith(
        color: highlightColor ?? Colors.black,
        fontWeight: FontWeight.w600,
      );
      Iterable matches = regExp.allMatches(text);
      Widget? timestampWidget;
      if (timestamp != null) {
        timestampWidget = Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(DateFormat.yMd().add_jm().format(timestamp),
              style: textTheme.caption),
        );
      }
      if (matches.isNotEmpty) {
        for (var match in matches) {
          /// First part
          if (match.start > initialPosition) {
            textFormatted.add(TextSpan(
              text: (text.substring(initialPosition!, match.start))
                  .replaceAll('_', ' ')
                  .replaceAll('{', '')
                  .replaceAll('}', ''),
            ));
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
            textFormatted.add(WidgetSpan(
              baseline: TextBaseline.alphabetic,
              alignment: PlaceholderAlignment.middle,
              child: UserChip(
                uid: cleanMatch,
                minimal: minimal,
                labelStyle: minimal ? textThemeColor : null,
              ),
            ));
          } else {
            textFormatted
                .add(TextSpan(text: cleanMatch, style: textThemeColor));
          }
          initialPosition = match.end;
        }

        /// Last part
        textFormatted.add(TextSpan(
          text: (text.substring(initialPosition!, text.length))
              .replaceAll('_', ' ')
              .replaceAll('{', ' ')
              .replaceAll('}', ' '),
        ));
      } else {
        textFormatted.add(TextSpan(text: text));
      }
      dynamic id = item.containsKey('id') ? item['id'] : null;
      List<PopupMenuEntry<String>> buttons = [];
      Widget? actionsWidgets;
      if (actions != null) {
        for (ButtonOptions option in actions!) {
          buttons.add(PopupMenuItem<String>(
            onTap: option.onTap != null ? () => option.onTap!(id) : null,
            child: Text(option.label),
          ));
        }
        actionsWidgets = Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            itemBuilder: (BuildContext context) => buttons,
          ),
        );
      }
      List<Widget> vertical = [];
      if (timestampWidget != null) vertical.add(timestampWidget);
      vertical.add(Text.rich(
        TextSpan(children: textFormatted),
        style: textThemeBase,
      ));
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
        itemCount: data!.length,
        itemBuilder: (BuildContext context, int index) => getItem(data![index]),
        padding: margin,
      );
    } else {
      final cellsBase =
          List.generate(data!.length, (index) => getItem(data![index]));
      return Padding(
        padding: margin,
        child: Flex(direction: Axis.vertical, children: cellsBase),
      );
    }
  }
}
