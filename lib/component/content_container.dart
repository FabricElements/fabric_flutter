import 'package:flutter/material.dart';

/// Defines the supported maximum-width breakpoints for [ContentContainer].
///
/// These values let callers pick a shared layout width without duplicating pixel
/// constants throughout the component layer.
enum ContentContainerSize {
  /// Fits narrow forms and dialogs into a compact layout.
  ///
  /// This value keeps short, focused content from stretching too wide on larger
  /// screens.
  small,

  /// Balances readability and density for standard page sections.
  ///
  /// This value serves as the default width for general-purpose content areas.
  medium,

  /// Expands the content area for data-heavy layouts.
  ///
  /// This value provides more horizontal room when a section benefits from wider
  /// presentation.
  large,

  /// Allows near full-width presentation while preserving centered alignment.
  ///
  /// This value suits wide dashboards or similar layouts that still need a maximum
  /// width cap.
  xLarge,
}

/// Centers content and constrains its maximum width for consistent page rhythm.
///
/// This widget is useful when the surrounding viewport can grow much wider than the
/// ideal reading width for forms or dense content. By applying a shared size system,
/// it keeps screens visually aligned across breakpoints without forcing each caller
/// to reimplement its own width calculations.
class ContentContainer extends StatelessWidget {
  /// Creates a centered container around either a single [child] or a [children] list.
  ///
  /// The assertion requires at least one of [child] or [children] to be non-`null`
  /// so the widget always has content to render.
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

  /// Stores the single widget to render when no internal [Flex] is needed.
  ///
  /// This value takes precedence over [children] when both are provided.
  final Widget? child;

  /// Stores the flex children to render when the widget builds its own [Flex].
  ///
  /// This list is used only when [child] is `null`.
  final List<Widget>? children;

  /// Stores the maximum width selection applied before the content is centered.
  ///
  /// The chosen [ContentContainerSize] maps to a fixed pixel width inside [build].
  final ContentContainerSize size;

  /// Stores the inner spacing around the rendered content.
  ///
  /// This padding is passed directly to the underlying [Container].
  final EdgeInsetsGeometry? padding;

  /// Stores the outer spacing around the constrained content block.
  ///
  /// This margin separates the centered container from surrounding widgets.
  final EdgeInsetsGeometry? margin;

  /// Stores the axis used when [children] are wrapped in an internal [Flex].
  ///
  /// This value is ignored when [child] provides the rendered content directly.
  final Axis direction;

  /// Stores how much space the internal [Flex] occupies along its main axis.
  ///
  /// This value is forwarded to [Flex.mainAxisSize] when [children] are rendered.
  final MainAxisSize mainAxisSize;

  /// Stores how the internal [Flex] aligns [children] across the cross axis.
  ///
  /// This value is forwarded to [Flex.crossAxisAlignment] when [children] are rendered.
  final CrossAxisAlignment crossAxisAlignment;

  /// Stores how the internal [Flex] aligns [children] along the main axis.
  ///
  /// This value is forwarded to [Flex.mainAxisAlignment] when [children] are rendered.
  final MainAxisAlignment mainAxisAlignment;

  /// Builds the constrained content tree for the current [BuildContext].
  ///
  /// The method maps [size] to a maximum width, renders either [child] or an
  /// internal [Flex], and then stretches the chosen content to fill the available
  /// width inside the centered container.
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
