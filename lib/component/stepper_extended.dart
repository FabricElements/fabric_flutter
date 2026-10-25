import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/density_spacing.dart';
import '../helper/log_color.dart';
import '../helper/scroll_reveal.dart';
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
    this.onError,
    this.controller,
  });

  /// Converts JSON-like step maps into [Step]s, so a surface can render the
  /// stepper from plain props without any stateful wiring.
  ///
  /// Each entry reads `title` (required), `subtitle`, `content` (all text) and
  /// `state` (`indexed`, `editing`, `complete`, `disabled` or `error`).
  /// Entries that are not maps are skipped; a `null` list yields no steps.
  static List<Step> stepsFromJson(List<dynamic>? json) => [
    for (final entry in json ?? const [])
      if (entry is Map)
        Step(
          title: Text('${entry['title'] ?? ''}'),
          subtitle: entry['subtitle'] != null
              ? Text('${entry['subtitle']}')
              : null,
          content: Text('${entry['content'] ?? ''}'),
          state: StepState.values.firstWhere(
            (value) => value.name == entry['state'],
            orElse: () => StepState.indexed,
          ),
        ),
  ];

  /// Optional handle used to reveal a step or content inside a step.
  ///
  /// Works with [scrollable] on and off: when off, the reveal scrolls the
  /// enclosing scrollable (for example a chat list).
  final StepperExtendedController? controller;

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

  /// Reports errors thrown by [onScrollOffsetChanged].
  ///
  /// Optional — if omitted, errors are only logged via `debugPrint` under
  /// `kDebugMode` instead of being swallowed silently.
  final ValueChanged<String>? onError;

  /// Creates state that manages the initial scroll position callback behavior.
  @override
  State<StepperExtended> createState() => _StepperExtendedState();
}

/// Reveals steps of a [StepperExtended] in the enclosing scrollables.
///
/// Pass one instance to [StepperExtended.controller]. Calls return `false`
/// while no stepper is attached.
class StepperExtendedController {
  _StepperExtendedState? _state;

  /// Scrolls the step at [index] into view.
  ///
  /// When [within] is given and mounted (for example a [GlobalKey] on a field
  /// inside the step's content), that widget is revealed instead, so an agent
  /// can land on the exact control it is working on. Returns `true` when the
  /// target ended in view.
  Future<bool> revealStep(
    int index, {
    GlobalKey? within,
    double alignment = 0.1,
  }) async {
    final state = _state;
    if (state == null) return false;
    return state._reveal(index, within, alignment);
  }
}

/// Owns the scroll controller used to report position changes for [StepperExtended].
class _StepperExtendedState extends State<StepperExtended> {
  /// Persists the configured initial offset and exposes scroll updates to the parent.
  late ScrollController _controller;

  /// Keys that locate each step body for [StepperExtendedController].
  final List<GlobalKey> _stepKeys = [];

  /// Initializes the controller before the first frame so scroll restoration is stable.
  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _controller = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
    );

    /// Scroll controller
    _controller.addListener(() async {
      try {
        widget.onScrollOffsetChanged?.call(_controller.offset);
      } catch (error) {
        _reportError('StepperExtended.onScrollOffsetChanged threw: $error');
      }
    });
  }

  /// Reports an error through [StepperExtended.onError], falling back to a
  /// debug log (under [kDebugMode]) when no handler is registered, or when
  /// the registered handler itself throws.
  void _reportError(String message) {
    if (widget.onError == null) {
      if (kDebugMode) debugPrint(LogColor.error(message));
      return;
    }
    try {
      widget.onError!(message);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(LogColor.error('StepperExtended.onError threw: $error'));
      }
    }
  }

  @override
  void didUpdateWidget(covariant StepperExtended oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
  }

  /// Implements [StepperExtendedController.revealStep].
  Future<bool> _reveal(int index, GlobalKey? within, double alignment) async {
    if (index < 0 || index >= widget.steps.length) return false;
    // Waits one frame so a step that was just added is laid out first.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return false;
    final context = within?.currentContext ?? _stepKeys[index].currentContext;
    if (context == null || !context.mounted) return false;
    return ScrollReveal.reveal(context, alignment: alignment);
  }

  /// Disposes the owned controller to avoid leaking listeners after removal.
  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    _controller.dispose();
    super.dispose();
  }

  /// Builds the step list and optionally wraps it in scroll affordances.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final locales = AppLocalizations.of(context);
    final density = DensitySpacing.of(context);
    while (_stepKeys.length < widget.steps.length) {
      _stepKeys.add(GlobalKey());
    }
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
      // Builds the accessible label announced for this step, since the
      // leading circle (number/icon) is decorative and excluded from
      // semantics below.
      String stepLabel = '${locales.get('label--step')} ${index + 1}';
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
          stepLabel = '$stepLabel, ${locales.get('label--done')}';
          break;
        case StepState.error:
          leadingContent = Text('!', style: leadingStyle);
          leadingColor = Colors.red;
          stepLabel = '$stepLabel, ${locales.get('label--step-error')}';
          break;
        default:
          leadingContent = Text((index + 1).toString(), style: leadingStyle);
          break;
      }

      Widget leading = ExcludeSemantics(
        child: Container(
          width: 32.0,
          height: 32.0,
          decoration: BoxDecoration(
            color: leadingColor,
            shape: BoxShape.circle,
          ),
          child: Center(child: leadingContent),
        ),
      );
      return ContentContainer(
        key: ValueKey('stepper_extended_step_$index'),
        margin: density.only(
          top: 16,
          bottom: 32,
          left: 0,
          right: 16,
          minVertical: 8,
          minHorizontal: 8,
        ),
        size: widget.size,
        child: Flex(
          key: widget.controller == null ? null : _stepKeys[index],
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: density.gap(16),
          children: [
            // MergeSemantics combines the leading state, title, and subtitle
            // into a single announcement per step; selected:true marks the
            // step currently being edited as the current step, and
            // inMutuallyExclusiveGroup:true (together with the outer group
            // Semantics below) lets assistive technology announce
            // "step N of M, selected" like a radio group.
            MergeSemantics(
              child: Semantics(
                label: stepLabel,
                selected: step.state == StepState.editing,
                inMutuallyExclusiveGroup: true,
                child: ListTile(
                  leading: leading,
                  title: step.title,
                  titleTextStyle: widget.titleTextStyle,
                  subtitle: step.subtitle != null
                      ? Padding(
                          padding: density.only(top: 8, minVertical: 4),
                          child: step.subtitle,
                        )
                      : null,
                  subtitleTextStyle: widget.subtitleTextStyle,
                  minLeadingWidth: 32,
                  isThreeLine: step.subtitle != null,
                ),
              ),
            ),
            Container(
              padding: density.only(left: 32, minHorizontal: 8),
              margin: density.only(left: 32, minHorizontal: 8),
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

    // A group label lets assistive technology announce the whole step list
    // as one navigable set of mutually-exclusive-state options, matching the
    // "step N of M" pattern used by radio groups.
    final content = Semantics(
      container: true,
      label: locales.get('label--steps'),
      child: Flex(
        direction: Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );

    if (widget.scrollable) {
      return Scrollbar(
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        controller: _controller,
        child: SingleChildScrollView(
          controller: _controller,
          padding: widget.padding,
          restorationId: widget.key?.toString() ?? 'stepper_extended',
          child: content,
        ),
      );
    }
    return Padding(padding: widget.padding, child: content);
  }
}
