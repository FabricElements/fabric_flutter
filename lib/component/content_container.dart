import 'package:flutter/material.dart';

enum ContentContainerSize {
  small,
  medium,
  large,
  xLarge,
}

class ContentContainer extends StatelessWidget {
  const ContentContainer({
    Key? key,
    this.child,
    this.size = ContentContainerSize.medium,
    this.padding,
    this.margin,
    this.children,
    this.direction = Axis.vertical,
    this.mainAxisSize = MainAxisSize.max,
  })  : assert(child != null || children != null,
            'child or children must be specified'),
        super(key: key);
  final Widget? child;
  final List<Widget>? children;
  final ContentContainerSize size;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Axis direction;
  final MainAxisSize mainAxisSize;

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
          crossAxisAlignment: CrossAxisAlignment.start,
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
