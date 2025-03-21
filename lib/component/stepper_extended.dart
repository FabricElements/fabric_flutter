import 'package:flutter/material.dart';

import 'content_container.dart';

class StepperExtended extends StatelessWidget {
  const StepperExtended({
    super.key,
    required this.steps,
    this.size = ContentContainerSize.medium,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.scrollable = false,
    this.padding = EdgeInsets.zero,
  });

  final List<Step> steps;
  final ContentContainerSize size;

  /// The text style for ListTile's [title].
  ///
  /// If this property is null, then [ListTileThemeData.titleTextStyle] is used.
  /// If that is also null and [ThemeData.useMaterial3] is true, [TextTheme.bodyLarge]
  /// with [ColorScheme.onSurface] will be used. Otherwise, If ListTile style is
  /// [ListTileStyle.list], [TextTheme.titleMedium] will be used and if ListTile style
  /// is [ListTileStyle.drawer], [TextTheme.bodyLarge] will be used.
  final TextStyle? titleTextStyle;

  /// The text style for ListTile's [subtitle].
  ///
  /// If this property is null, then [ListTileThemeData.subtitleTextStyle] is used.
  /// If that is also null and [ThemeData.useMaterial3] is true, [TextTheme.bodyMedium]
  /// with [ColorScheme.onSurfaceVariant] will be used, otherwise [TextTheme.bodyMedium]
  /// with [TextTheme.bodySmall] color will be used.
  final TextStyle? subtitleTextStyle;

  /// If true, the stepper will be displayed on a [ListView].
  final bool scrollable;

  /// The padding of the stepper.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    List<Widget> children = List.generate(steps.length, (index) {
      Step step = steps[index];
      TextStyle? leadingStyle = textTheme.titleMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      );
      Widget leadingContent = const SizedBox();
      const iconColor = Colors.white;
      const iconSize = 18.0;
      Color leadingColor = Colors.grey.shade800;
      switch (step.state) {
        // case StepState.indexed:
        // case StepState.disabled:
        case StepState.editing:
          leadingContent = const Icon(
            Icons.edit,
            color: iconColor,
            size: iconSize,
          );
          break;
        case StepState.complete:
          leadingContent = const Icon(
            Icons.check,
            color: iconColor,
            size: iconSize,
          );
          leadingColor = Colors.teal;
          break;
        case StepState.error:
          leadingContent = Text('!', style: leadingStyle);
          leadingColor = Colors.red;
          break;
        default:
          leadingContent = Text(
            (index + 1).toString(),
            style: leadingStyle,
          );
          break;
      }

      Widget leading = Container(
        width: 32.0,
        height: 32.0,
        decoration: BoxDecoration(
          color: leadingColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: leadingContent,
        ),
      );
      return ContentContainer(
        margin: const EdgeInsets.only(top: 16, bottom: 32, left: 0, right: 16),
        size: size,
        child: Flex(
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: leading,
              title: step.title,
              titleTextStyle: titleTextStyle,
              subtitle: step.subtitle,
              subtitleTextStyle: subtitleTextStyle,
              minLeadingWidth: 32,
              isThreeLine: step.subtitle != null,
            ),
            Container(
              padding: const EdgeInsets.only(left: 32),
              margin: const EdgeInsets.only(left: 32),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              child: step.content,
            )
          ],
        ),
      );
    });

    if (scrollable) {
      return ListView(
        restorationId: key?.toString() ?? 'stepper_extended',
        padding: padding,
        children: children,
      );
    }
    return Padding(
      padding: padding,
      child: Flex(
        direction: Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
