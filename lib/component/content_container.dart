import 'package:flutter/material.dart';

enum ContentContainerSize {
  small,
  medium,
  large,
  xLarge,
}

class ContentContainer extends StatelessWidget {
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
  }) : assert(child != null || children != null,
            'child or children must be specified');
  final Widget? child;
  final List<Widget>? children;

  /// [size] of the container
  final ContentContainerSize size;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Axis direction;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

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
    Widget content = child ??
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
        child: SizedBox(
          width: double.maxFinite,
          child: content,
        ),
      ),
    );
  }
}
