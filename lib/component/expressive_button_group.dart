import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../helper/agent/agent_element_binding.dart';
import '../helper/density_spacing.dart';
import '../helper/m3_expressive_shape_border.dart';
import '../helper/m3_tokens.dart';
import '../serialized/agent_element_snapshot.dart';

/// One segment of an [ExpressiveButtonGroup].
class ExpressiveButtonItem<T> {
  /// Creates a segment that reports [value] when selected.
  const ExpressiveButtonItem({
    required this.value,
    required this.label,
    this.icon,
    this.automationKey,
  });

  /// Value reported to [ExpressiveButtonGroup.onChanged] and compared with its
  /// selection.
  final T value;

  /// Text shown inside the segment and used as its accessible label.
  final String label;

  /// Optional icon shown before [label].
  final IconData? icon;

  /// Stable identifier that publishes this segment to the agent element index.
  final String? automationKey;
}

/// Row of single-selection segments whose selected segment springs into a cookie.
///
/// Each segment is a separate soft-squircle shape. When a segment becomes
/// selected, its outline springs into a lobed cookie and it takes the primary
/// container colour, so the selection reads through shape as well as colour.
class ExpressiveButtonGroup<T> extends StatelessWidget {
  /// Creates a group that shows [items] and marks [selected] as active.
  ///
  /// Passing a `null` [onChanged] renders every segment disabled.
  const ExpressiveButtonGroup({
    super.key,
    required this.items,
    required this.selected,
    this.onChanged,
  });

  /// Segments to show, in left-to-right order.
  final List<ExpressiveButtonItem<T>> items;

  /// Value of the selected segment, or `null` when nothing is selected.
  final T? selected;

  /// Runs with the tapped segment's value, or `null` to disable the group.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final density = DensitySpacing.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) SizedBox(width: density.gap(8)),
          Expanded(
            child: _ExpressiveSegment<T>(
              item: items[index],
              selected: items[index].value == selected,
              onChanged: onChanged,
              padding: density.symmetric(
                horizontal: 12,
                vertical: 14,
                minVertical: 56,
              ),
              labelStyle: textTheme.titleSmall,
              colorScheme: colorScheme,
            ),
          ),
        ],
      ],
    );
  }
}

/// One selectable segment of an [ExpressiveButtonGroup].
class _ExpressiveSegment<T> extends StatefulWidget {
  const _ExpressiveSegment({
    required this.item,
    required this.selected,
    required this.onChanged,
    required this.padding,
    required this.labelStyle,
    required this.colorScheme,
  });

  final ExpressiveButtonItem<T> item;
  final bool selected;
  final ValueChanged<T>? onChanged;
  final EdgeInsets padding;
  final TextStyle? labelStyle;
  final ColorScheme colorScheme;

  @override
  State<_ExpressiveSegment<T>> createState() => _ExpressiveSegmentState<T>();
}

class _ExpressiveSegmentState<T> extends State<_ExpressiveSegment<T>>
    with SingleTickerProviderStateMixin {
  /// Drives the selection morph: 0 is unselected, 1 is selected.
  late final AnimationController _select = AnimationController.unbounded(
    vsync: this,
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _ExpressiveSegment<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _select.animateWith(
        SpringSimulation(
          M3ExpressiveMotion.spring,
          _select.value,
          widget.selected ? 1 : 0,
          0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _select.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final density = DensitySpacing.of(context);
    final enabled = widget.onChanged != null;
    final item = widget.item;
    final colorScheme = widget.colorScheme;
    final VoidCallback? activate = enabled
        ? () => widget.onChanged!(item.value)
        : null;

    return AgentElement(
      id: item.automationKey,
      type: AgentElementType.button,
      label: item.label,
      enabledGetter: () => enabled,
      activator: activate,
      child: Semantics(
        button: true,
        selected: widget.selected,
        enabled: enabled,
        label: item.label,
        identifier: item.automationKey,
        container: true,
        excludeSemantics: true,
        onTap: activate,
        child: AnimatedBuilder(
          animation: _select,
          builder: (context, child) {
            final t = _select.value;
            final shape = ExpressiveShapeBorder.lerp(
              ExpressiveShapeBorder.squircle,
              ExpressiveShapeBorder.cookie,
              t,
            );
            final background = Color.lerp(
              colorScheme.surfaceContainerHighest,
              colorScheme.primaryContainer,
              t,
            )!;
            final foreground = Color.lerp(
              colorScheme.onSurface,
              colorScheme.onPrimaryContainer,
              t,
            )!;
            return Transform.scale(
              scale: 1 + 0.04 * t,
              child: Material(
                color: background,
                shape: shape,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: shape,
                  onTap: activate,
                  child: Padding(
                    padding: widget.padding,
                    child: _SegmentContent(
                      item: item,
                      color: foreground,
                      labelStyle: widget.labelStyle,
                      gap: density.gap(8),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Icon and label of one segment, drawn in [color].
class _SegmentContent<T> extends StatelessWidget {
  const _SegmentContent({
    required this.item,
    required this.color,
    required this.labelStyle,
    required this.gap,
  });

  final ExpressiveButtonItem<T> item;
  final Color color;
  final TextStyle? labelStyle;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.icon != null) ...[
          Icon(item.icon, size: 20, color: color),
          SizedBox(width: gap),
        ],
        Flexible(
          child: Text(
            item.label,
            overflow: TextOverflow.ellipsis,
            style: labelStyle?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
