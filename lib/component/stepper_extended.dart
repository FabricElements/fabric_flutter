import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/density_spacing.dart';
import '../helper/log_color.dart';
import '../helper/scroll_reveal.dart';
import 'content_container.dart';

/// Displays a vertically stacked stepper with a continuous connector rail.
///
/// This variant exists for flows that need richer layout control than
/// Flutter's built-in [Stepper], while still exposing familiar [Step] data
/// and scroll behavior for long forms and onboarding experiences.
///
/// Every step renders a fixed leading indicator column — a circular state
/// badge with a connector segment below it — beside a single text column
/// holding the title, subtitle and content. The connector segments of all
/// steps join into one continuous rail down the left side of the stepper,
/// and all step text shares one left edge at every width, so compact
/// screens and nested steppers keep a clear, aligned reading line.
class StepperExtended extends StatefulWidget {
  /// Creates a stepper that renders its steps around a connector rail.
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

  /// Optional handle used to reveal a step or content inside a step.
  ///
  /// Works with [scrollable] on and off: when off, the reveal scrolls the
  /// enclosing scrollable (for example a chat list).
  final RevealController? controller;

  /// The ordered steps to render from top to bottom.
  final List<Step> steps;

  /// Controls the width preset applied to the [ContentContainer] that wraps
  /// the whole step list.
  final ContentContainerSize size;

  /// The text style for the step [Step.title].
  ///
  /// If this property is null, then [ListTileThemeData.titleTextStyle] is
  /// used for compatibility. If that is also null, [TextTheme.bodyLarge]
  /// with [ColorScheme.onSurface] will be used.
  final TextStyle? titleTextStyle;

  /// The text style for the step [Step.subtitle].
  ///
  /// If this property is null, then [ListTileThemeData.subtitleTextStyle] is
  /// used for compatibility. If that is also null, [TextTheme.bodyMedium]
  /// with [ColorScheme.onSurfaceVariant] will be used.
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
/// Pass one instance to [StepperExtended.controller] and call
/// [RevealController.reveal] with the step index, or with a [RevealTarget]
/// wrapping the index and a [RevealTarget.within] key. Calls return `false`
/// while no stepper is attached.
class _StepperRevealHandler implements RevealHandler {
  _StepperRevealHandler(this._state);

  final _StepperExtendedState _state;

  @override
  Future<bool> revealTarget(Object target, double alignment) {
    final int index;
    GlobalKey? within;
    if (target is RevealTarget) {
      final inner = target.target;
      if (inner is! int) return Future.value(false);
      index = inner;
      within = target.within;
    } else if (target is int) {
      index = target;
    } else {
      return Future.value(false);
    }
    return _state._reveal(index, within, alignment);
  }
}

/// Owns the scroll controller used to report position changes for [StepperExtended].
class _StepperExtendedState extends State<StepperExtended> {
  /// Persists the configured initial offset and exposes scroll updates to the parent.
  late ScrollController _controller;

  /// Bridges [StepperExtended.controller] to this state.
  late final _StepperRevealHandler _revealHandler = _StepperRevealHandler(this);

  /// Keys that locate each step for [StepperExtended.controller].
  final List<GlobalKey> _stepKeys = [];

  /// Initializes the controller before the first frame so scroll restoration is stable.
  @override
  void initState() {
    super.initState();
    widget.controller?.attach(_revealHandler);
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
      oldWidget.controller?.detach(_revealHandler);
      widget.controller?.attach(_revealHandler);
    }
  }

  /// Implements [RevealController.reveal] for a step index or [RevealTarget].
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
    widget.controller?.detach(_revealHandler);
    _controller.dispose();
    super.dispose();
  }

  /// Builds the circular state badge shown at the top of the step's
  /// indicator column.
  ///
  /// The badge colors come from the ambient [ColorScheme] so the stepper
  /// follows the Material 3 theme instead of hardcoded greys: the step
  /// being edited uses [ColorScheme.primary], completed steps use
  /// [ColorScheme.primaryContainer], error steps use
  /// [ColorScheme.errorContainer], and upcoming steps use
  /// [ColorScheme.secondaryContainer].
  Widget _buildBadge(Step step, int index, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final Color badgeColor;
    final Color badgeContentColor;
    switch (step.state) {
      case StepState.editing:
        badgeColor = colorScheme.primary;
        badgeContentColor = colorScheme.onPrimary;
        break;
      case StepState.complete:
        badgeColor = colorScheme.primaryContainer;
        badgeContentColor = colorScheme.onPrimaryContainer;
        break;
      case StepState.error:
        badgeColor = colorScheme.errorContainer;
        badgeContentColor = colorScheme.onErrorContainer;
        break;
      default:
        badgeColor = colorScheme.secondaryContainer;
        badgeContentColor = colorScheme.onSecondaryContainer;
        break;
    }
    final badgeStyle = theme.textTheme.titleMedium?.copyWith(
      color: badgeContentColor,
      fontWeight: FontWeight.w700,
    );
    final Widget badgeContent = switch (step.state) {
      StepState.editing => Icon(Icons.edit, color: badgeContentColor, size: 18),
      StepState.complete => Icon(
        Icons.check,
        color: badgeContentColor,
        size: 18,
      ),
      StepState.error => Text('!', style: badgeStyle),
      _ => Text('${index + 1}', style: badgeStyle),
    };
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
      child: Center(child: badgeContent),
    );
  }

  /// Builds one step: a fixed indicator column (badge plus the connector
  /// segment that joins this step to the next one) beside an [Expanded]
  /// text column holding the title, subtitle and content.
  ///
  /// The row stretches to the step's full height so the connector segment
  /// fills the space below the badge and the rail reads as one continuous
  /// line across steps. All vertical rhythm lives inside the text column
  /// (as its bottom padding) so the outer step list carries no spacing that
  /// would break the rail at step boundaries.
  Widget _buildStep(
    BuildContext context,
    int index,
    DensitySpacing density,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locales = AppLocalizations.of(context);
    final step = widget.steps[index];
    final isLast = index == widget.steps.length - 1;

    // Builds the accessible label announced for this step, since the
    // leading circle (number/icon) is decorative and excluded from
    // semantics below.
    String stepLabel = '${locales.get('label--step')} ${index + 1}';
    switch (step.state) {
      case StepState.complete:
        stepLabel = '$stepLabel, ${locales.get('label--done')}';
        break;
      case StepState.error:
        stepLabel = '$stepLabel, ${locales.get('label--step-error')}';
        break;
      default:
        break;
    }

    final Widget indicatorColumn = ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBadge(step, index, colorScheme),
          if (!isLast)
            Expanded(
              child: Container(width: 2, color: colorScheme.outlineVariant),
            ),
        ],
      ),
    );

    final Widget textColumn = Expanded(
      child: Padding(
        // Bottom padding is the vertical rhythm between steps; it lives
        // here rather than on the step list so the connector segment
        // stretches across the full gap and the rail stays continuous.
        padding: density.only(bottom: 24, minVertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // MergeSemantics combines the leading state, title, and
            // subtitle into a single announcement per step; selected:true
            // marks the step currently being edited as the current step,
            // and inMutuallyExclusiveGroup:true (together with the outer
            // group Semantics below) lets assistive technology announce
            // "step N of M, selected" like a radio group.
            MergeSemantics(
              child: Semantics(
                label: stepLabel,
                selected: step.state == StepState.editing,
                inMutuallyExclusiveGroup: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle(
                      style: titleStyle ?? const TextStyle(),
                      child: step.title,
                    ),
                    if (step.subtitle != null)
                      Padding(
                        padding: density.only(top: 4, minVertical: 2),
                        child: DefaultTextStyle(
                          style: subtitleStyle ?? const TextStyle(),
                          child: step.subtitle!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: density.only(top: 12, minVertical: 8),
              child: KeyedSubtree(
                key: ValueKey('stepper_extended_step_body_$index'),
                child: step.content,
              ),
            ),
          ],
        ),
      ),
    );

    return IntrinsicHeight(
      child: Row(
        key: widget.controller == null ? null : _stepKeys[index],
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: density.gap(16, min: 8),
        children: [indicatorColumn, textColumn],
      ),
    );
  }

  /// Builds the step list and optionally wraps it in scroll affordances.
  ///
  /// The whole list sits inside one [ContentContainer] so the connector
  /// rail runs down a single continuous surface. Each step lays out its
  /// leading circle beside a single column holding the title, subtitle and
  /// content, so all step text shares one left edge at every width —
  /// compact screens included — and nested steppers never compound
  /// horizontal indentation because no width-responsive indent exists.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final listTileTheme = ListTileTheme.of(context);
    final density = DensitySpacing.of(context);
    while (_stepKeys.length < widget.steps.length) {
      _stepKeys.add(GlobalKey());
    }

    final TextStyle? titleStyle =
        widget.titleTextStyle ??
        listTileTheme.titleTextStyle ??
        textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface);
    final TextStyle? subtitleStyle =
        widget.subtitleTextStyle ??
        listTileTheme.subtitleTextStyle ??
        textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);

    final List<Widget> children = List.generate(widget.steps.length, (index) {
      return _buildStep(context, index, density, titleStyle, subtitleStyle);
    });

    // A group label lets assistive technology announce the whole step list
    // as one navigable set of mutually-exclusive-state options, matching the
    // "step N of M" pattern used by radio groups.
    final content = Semantics(
      container: true,
      label: AppLocalizations.of(context).get('label--steps'),
      child: ContentContainer(
        size: widget.size,
        child: Flex(
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
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
