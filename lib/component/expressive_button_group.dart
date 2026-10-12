import 'package:flutter/material.dart';

import '../serialized/agent_element_snapshot.dart';
import '../helper/agent/agent_element_binding.dart';
import '../helper/density_spacing.dart';
import '../helper/m3_tokens.dart';

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

/// Connected row of mutually exclusive buttons with a morphing selection.
///
/// Segments sit edge to edge. The outer ends are fully rounded, and the inner
/// corners stay small until a segment is selected. The selected segment morphs
/// all of its corners to a larger radius and takes the primary container
/// colour, so the selection reads through shape as well as colour.
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
    final last = items.length - 1;

    return Row(
      children: [
        for (var index = 0; index < items.length; index++)
          Expanded(
            child: _ExpressiveSegment<T>(
              item: items[index],
              isFirst: index == 0,
              isLast: index == last,
              selected: items[index].value == selected,
              onChanged: onChanged,
              padding: density.symmetric(
                horizontal: 12,
                vertical: 12,
                minVertical: 48,
              ),
              labelStyle: textTheme.labelLarge,
              colorScheme: colorScheme,
            ),
          ),
      ],
    );
  }
}

/// One selectable segment of an [ExpressiveButtonGroup].
class _ExpressiveSegment<T> extends StatelessWidget {
  const _ExpressiveSegment({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.selected,
    required this.onChanged,
    required this.padding,
    required this.labelStyle,
    required this.colorScheme,
  });

  final ExpressiveButtonItem<T> item;
  final bool isFirst;
  final bool isLast;
  final bool selected;
  final ValueChanged<T>? onChanged;
  final EdgeInsets padding;
  final TextStyle? labelStyle;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final density = DensitySpacing.of(context);
    final enabled = onChanged != null;
    final shape = _shape();
    final background = selected
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final VoidCallback? activate = enabled
        ? () => onChanged!(item.value)
        : null;

    final content = Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.icon != null) ...[
            Icon(item.icon, size: 18, color: foreground),
            SizedBox(width: density.gap(8)),
          ],
          Flexible(
            child: Text(
              item.label,
              overflow: TextOverflow.ellipsis,
              style: labelStyle?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );

    return AgentElement(
      id: item.automationKey,
      type: AgentElementType.button,
      label: item.label,
      enabledGetter: () => enabled,
      activator: activate,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        label: item.label,
        identifier: item.automationKey,
        container: true,
        excludeSemantics: true,
        onTap: activate,
        child: AnimatedContainer(
          duration: M3Motion.medium2,
          curve: M3Motion.standard,
          decoration: ShapeDecoration(color: background, shape: shape),
          child: InkWell(customBorder: shape, onTap: activate, child: content),
        ),
      ),
    );
  }

  /// Returns the morphing outline for this segment's current state.
  ShapeBorder _shape() {
    final outer = M3Shape.full;
    final inner = selected
        ? M3ExpressiveShape.segmentSelected
        : M3ExpressiveShape.segmentInner;
    final left = isFirst ? outer : inner;
    final right = isLast ? outer : inner;
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(left),
        bottomLeft: Radius.circular(left),
        topRight: Radius.circular(right),
        bottomRight: Radius.circular(right),
      ),
    );
  }
}
