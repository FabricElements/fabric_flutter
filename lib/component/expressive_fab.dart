import 'package:flutter/material.dart';

import '../serialized/agent_element_snapshot.dart';
import '../helper/agent/agent_element_binding.dart';
import '../helper/m3_tokens.dart';

/// Size presets for [ExpressiveFab], following the Material 3 Expressive FAB sizes.
enum ExpressiveFabSize {
  /// Compact 56dp action for dense layouts.
  small,

  /// Default 80dp action for the primary action of a screen.
  medium,

  /// Prominent 96dp action for large or empty-state screens.
  large,
}

/// Floating action button that morphs its shape while pressed.
///
/// The FAB rests as a rounded square and morphs into a circle while the user
/// holds it, so the press itself is visible without a separate ripple. Three
/// [ExpressiveFabSize] presets cover the Material 3 Expressive sizes. The
/// button is published to the agent element index when [automationKey] is set,
/// in the same way as `SmartButton`.
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

class _ExpressiveFabState extends State<ExpressiveFab> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spec = _ExpressiveFabSpec.of(widget.size);
    final enabled = widget.onPressed != null;
    final radius = _pressed ? M3ExpressiveShape.fabPressed : spec.radius;
    final shape = M3ExpressiveShape.rounded(radius);
    final background = enabled
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foreground = enabled
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    Widget button = SizedBox.square(
      dimension: spec.container,
      child: AnimatedContainer(
        duration: M3Motion.medium2,
        curve: M3Motion.standard,
        decoration: ShapeDecoration(color: background, shape: shape),
        child: InkWell(
          customBorder: shape,
          onTap: widget.onPressed,
          onHighlightChanged: enabled ? _setPressed : null,
          child: Center(
            child: Icon(widget.icon, size: spec.icon, color: foreground),
          ),
        ),
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

/// Container, icon and resting radius for one [ExpressiveFabSize].
class _ExpressiveFabSpec {
  const _ExpressiveFabSpec({
    required this.container,
    required this.icon,
    required this.radius,
  });

  /// Returns the spec for [size].
  factory _ExpressiveFabSpec.of(ExpressiveFabSize size) {
    return switch (size) {
      ExpressiveFabSize.small => const _ExpressiveFabSpec(
        container: 56,
        icon: 24,
        radius: M3ExpressiveShape.fabSmall,
      ),
      ExpressiveFabSize.medium => const _ExpressiveFabSpec(
        container: 80,
        icon: 28,
        radius: M3ExpressiveShape.fabLarge,
      ),
      ExpressiveFabSize.large => const _ExpressiveFabSpec(
        container: 96,
        icon: 36,
        radius: M3ExpressiveShape.fabLarge,
      ),
    };
  }

  /// Width and height of the square container, in logical pixels.
  final double container;

  /// Icon size, in logical pixels.
  final double icon;

  /// Resting corner radius, before the press morph.
  final double radius;
}
