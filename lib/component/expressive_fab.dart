import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../helper/m3_expressive_shape_border.dart';
import '../helper/m3_tokens.dart';
import '../serialized/agent_element_snapshot.dart';
import '../helper/agent/agent_element_binding.dart';

/// Size presets for [ExpressiveFab], following the Material 3 Expressive FAB sizes.
enum ExpressiveFabSize {
  /// Compact 56dp action for dense layouts.
  small,

  /// Default 80dp action for the primary action of a screen.
  medium,

  /// Prominent 96dp action for large or empty-state screens.
  large,
}

/// Floating action button that springs into a lobed cookie shape while pressed.
///
/// At rest the FAB is a soft squircle. While the user holds it, the outline
/// morphs into a cookie and the button scales down slightly. Releasing springs
/// it back with a small overshoot, which is the Material 3 Expressive motion.
/// The button is published to the agent element index when [automationKey] is
/// set, in the same way as `SmartButton`.
class ExpressiveFab extends StatefulWidget {
  /// Creates a FAB showing [icon] that runs [onPressed] when tapped.
  ///
  /// [semanticsLabel] describes the action for assistive technologies because
  /// the FAB has no visible text. A `null` [onPressed] renders the disabled
  /// state.
  const ExpressiveFab({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    this.onPressed,
    this.size = ExpressiveFabSize.medium,
    this.tooltip,
    this.automationKey,
  });

  /// Icon drawn at the centre of the button.
  final IconData icon;

  /// Describes the action for assistive technologies, such as `'Create message'`.
  final String semanticsLabel;

  /// Runs when the FAB is tapped, or `null` to render the disabled state.
  final VoidCallback? onPressed;

  /// Size preset that sets the container and icon dimensions.
  final ExpressiveFabSize size;

  /// Text shown on long press, or `null` to show no tooltip.
  final String? tooltip;

  /// Stable identifier that publishes this FAB to the agent element index.
  final String? automationKey;

  @override
  State<ExpressiveFab> createState() => _ExpressiveFabState();
}

class _ExpressiveFabState extends State<ExpressiveFab>
    with SingleTickerProviderStateMixin {
  /// Drives the press morph: 0 is the resting squircle, 1 is the pressed cookie.
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  /// Whether a tap is playing its press morph before [ExpressiveFab.onPressed].
  bool _tapping = false;

  /// Springs the morph to [target] and returns a future that completes once settled.
  TickerFuture _springTo(double target) {
    return _press.animateWith(
      SpringSimulation(M3ExpressiveMotion.spring, _press.value, target, 0),
    );
  }

  /// Plays the full press morph, runs [ExpressiveFab.onPressed], then releases.
  ///
  /// The action waits for the cookie to settle, so the morph is visible even
  /// when the action navigates away and disposes this button.
  Future<void> _handleTap() async {
    final onPressed = widget.onPressed;
    if (onPressed == null) return;
    _tapping = true;
    await _springTo(1);
    if (!mounted) return;
    onPressed();
    _tapping = false;
    if (mounted) _springTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spec = _ExpressiveFabSpec.of(widget.size);
    final enabled = widget.onPressed != null;
    final background = enabled
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foreground = enabled
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    Widget button = SizedBox.square(
      dimension: spec.container,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          final t = _press.value;
          final shape = ExpressiveShapeBorder.lerp(
            ExpressiveShapeBorder.squircle,
            ExpressiveShapeBorder.cookie,
            t,
          );
          return Transform.scale(
            scale: 1 - 0.08 * t,
            child: Material(
              color: background,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: shape,
                onTap: enabled ? _handleTap : null,
                onHighlightChanged: (highlighted) {
                  if (!enabled) return;
                  if (highlighted || !_tapping) {
                    _springTo(highlighted ? 1 : 0);
                  }
                },
                child: Center(
                  child: Icon(widget.icon, size: spec.icon, color: foreground),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip, child: button);
    }

    return AgentElement(
      id: widget.automationKey,
      type: AgentElementType.button,
      label: widget.semanticsLabel,
      enabledGetter: () => enabled,
      activator: widget.onPressed,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.semanticsLabel,
        identifier: widget.automationKey,
        container: true,
        child: button,
      ),
    );
  }
}

/// Container and icon size for one [ExpressiveFabSize].
class _ExpressiveFabSpec {
  const _ExpressiveFabSpec({required this.container, required this.icon});

  /// Returns the spec for [size].
  factory _ExpressiveFabSpec.of(ExpressiveFabSize size) {
    return switch (size) {
      ExpressiveFabSize.small => const _ExpressiveFabSpec(
        container: 56,
        icon: 24,
      ),
      ExpressiveFabSize.medium => const _ExpressiveFabSpec(
        container: 80,
        icon: 28,
      ),
      ExpressiveFabSize.large => const _ExpressiveFabSpec(
        container: 96,
        icon: 36,
      ),
    };
  }

  /// Width and height of the square container, in logical pixels.
  final double container;

  /// Icon size, in logical pixels.
  final double icon;
}
