import 'package:flutter/material.dart';

/// Defines the supported maximum-width breakpoints for [ContentContainer].
enum ContentContainerSize {
  /// Fits narrow forms and dialogs that should remain compact on desktop layouts.
  small,

  /// Balances readability and density for most standard page sections.
  medium,

  /// Expands the content area for data-heavy or side-by-side layouts.
  large,

  /// Allows near full-width presentation while still centering the content block.
  xLarge
}

/// Centers content and constrains its maximum width for consistent page rhythm.
///
/// This widget is useful when the surrounding viewport can grow much wider than the
/// ideal reading width for forms or dense content. By applying a shared size system it
/// keeps screens visually aligned across breakpoints without forcing each caller to
/// reimplement its own width calculations.
class ContentContainer extends StatelessWidget {
  /// Creates a centered container around either a single [child] or a [children] list.
  const ContentContainer({
    super.key,
    this.child,
    this.size = ContentContainerSize.medium,
    this.padding,
    this.margin,
    this.children,
    this.direction = Axis.vertical,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
  }) : assert(
         child != null || children != null,
         'child or children must be specified',
       );
  /// Displays a single widget when callers do not need an internal flex layout.
  final Widget? child;
  /// Supplies flex children when the container should build its own [Flex] layout.
  final List<Widget>? children;

  /// Selects the maximum width applied before the content is centered.
  final ContentContainerSize size;
  /// Adds inner spacing around the rendered content.
  final EdgeInsetsGeometry? padding;
  /// Adds outer spacing around the constrained content block.
  final EdgeInsetsGeometry? margin;
  /// Chooses the axis used when [children] are wrapped in an internal [Flex].
  final Axis direction;
  /// Controls how much space the internal [Flex] occupies along its main axis.
  final MainAxisSize mainAxisSize;
  /// Aligns [children] across the cross axis of the internal [Flex].
  final CrossAxisAlignment crossAxisAlignment;
  /// Aligns [children] along the main axis of the internal [Flex].
  final MainAxisAlignment mainAxisAlignment;

  /// Applies the selected width constraint and then renders the provided content.
  @override
  Widget build(BuildContext context) {
    late double maxSize;
    switch (size) {
      case ContentContainerSize.small:
        maxSize = 500;
        break;
      case ContentContainerSize.medium:
        maxSize = 900;
        break;
      case ContentContainerSize.large:
        maxSize = 1200;
        break;
      case ContentContainerSize.xLarge:
        maxSize = 1700;
        break;
    }
    Widget content =
        child ??
        Flex(
          direction: direction,
          mainAxisSize: mainAxisSize,
          crossAxisAlignment: crossAxisAlignment,
          mainAxisAlignment: mainAxisAlignment,
          children: children!,
        );
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxSize),
        margin: margin,
        padding: padding,
        child: SizedBox(width: double.maxFinite, child: content),
      ),
    );
  }
}
