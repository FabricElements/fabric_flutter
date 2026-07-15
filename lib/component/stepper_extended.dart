import 'package:flutter/material.dart';

import 'content_container.dart';

/// Displays a vertically stacked stepper using [ContentContainer] sections.
///
/// This variant exists for flows that need richer layout control than Flutter's
/// built-in [Stepper], while still exposing familiar [Step] data and scroll
/// behavior for long forms and onboarding experiences.
class StepperExtended extends StatefulWidget {
  /// Creates a stepper that renders each [Step] inside a content container.
  const StepperExtended({
    super.key,
    required this.steps,
    this.size = ContentContainerSize.medium,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.scrollable = false,
    this.padding = EdgeInsets.zero,
    this.initialScrollOffset = 0.0,
    this.onScrollOffsetChanged,
  });

  /// The ordered steps to render from top to bottom.
  final List<Step> steps;

  /// Controls the width preset applied to each [ContentContainer].
  final ContentContainerSize size;

  /// The text style for ListTile's [title].
  ///
  /// If this property is null, then [ListTileThemeData.titleTextStyle] is used.
  /// If that is also null, [TextTheme.bodyLarge] with [ColorScheme.onSurface]
  /// will be used.
  final TextStyle? titleTextStyle;

  /// The text style for ListTile's [subtitle].
  ///
  /// If this property is null, then [ListTileThemeData.subtitleTextStyle] is used.
  /// If that is also null, [TextTheme.bodyMedium] with
  /// [ColorScheme.onSurfaceVariant] will be used.
  final TextStyle? subtitleTextStyle;

  /// If true, the stepper will be displayed on a [ListView].
  final bool scrollable;

  /// The padding of the stepper.
  final EdgeInsetsGeometry padding;

  /// Initial scroll offset
  final double initialScrollOffset;

  /// Callback when scroll offset changes
  final Function(double offset)? onScrollOffsetChanged;

  /// Creates state that manages the initial scroll position callback behavior.
  @override
  State<StepperExtended> createState() => _StepperExtendedState();
}

/// Owns the scroll controller used to report position changes for [StepperExtended].
class _StepperExtendedState extends State<StepperExtended> {
  /// Persists the configured initial offset and exposes scroll updates to the parent.
  late ScrollController _controller;

  /// Initializes the controller before the first frame so scroll restoration is stable.
  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
    );

    /// Scroll controller
    _controller.addListener(() async {
      widget.onScrollOffsetChanged?.call(_controller.offset);
    });
  }

  /// Disposes the owned controller to avoid leaking listeners after removal.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Builds the step list and optionally wraps it in scroll affordances.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final controller = ScrollController();
    List<Widget> children = List.generate(widget.steps.length, (index) {
      Step step = widget.steps[index];
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
          leadingContent = Text((index + 1).toString(), style: leadingStyle);
          break;
      }

      Widget leading = Container(
        width: 32.0,
        height: 32.0,
        decoration: BoxDecoration(color: leadingColor, shape: BoxShape.circle),
        child: Center(child: leadingContent),
      );
      return ContentContainer(
        key: ValueKey('stepper_extended_step_$index'),
        margin: const EdgeInsets.only(top: 16, bottom: 32, left: 0, right: 16),
        size: widget.size,
        child: Flex(
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            ListTile(
              leading: leading,
              title: step.title,
              titleTextStyle: widget.titleTextStyle,
              subtitle: step.subtitle != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: step.subtitle,
                    )
                  : null,
              subtitleTextStyle: widget.subtitleTextStyle,
              minLeadingWidth: 32,
              isThreeLine: step.subtitle != null,
            ),
            Container(
              padding: const EdgeInsets.only(left: 32),
              margin: const EdgeInsets.only(left: 32),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.surfaceContainerHigh,
                    width: 1,
                  ),
                ),
              ),
              child: step.content,
            ),
          ],
        ),
      );
    });

    final content = Flex(
      direction: Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );

    if (widget.scrollable) {
      return Scrollbar(
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        controller: controller,
        child: SingleChildScrollView(
          controller: controller,
          padding: widget.padding,
          restorationId: widget.key?.toString() ?? 'stepper_extended',
          child: content,
        ),
      );
    }
    return Padding(padding: widget.padding, child: content);
  }
}
