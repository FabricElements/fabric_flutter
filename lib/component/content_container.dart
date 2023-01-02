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
    required this.child,
    this.size = ContentContainerSize.medium,
    this.padding,
    this.margin,
  }) : super(key: key);
  final Widget child;
  final ContentContainerSize size;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

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
        maxSize = 2000;
        break;
    }
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxSize),
        margin: margin,
        padding: padding,
        child: child,
      ),
    );
  }
}
