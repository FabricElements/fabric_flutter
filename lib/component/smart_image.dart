import 'dart:async';

import 'package:flutter/material.dart';

import '../helper/utils.dart';

/// SmartImage can be used to display an image for basic Imgix or Internal implementation.
///
/// [url] This is the image url.
/// [size] Predefined sizes:
/// https://github.com/FabricElements/shared-helpers/blob/master/src/image-helper.ts#L17
///
/// SmartImage(
///   url: 'https://images.unsplash.com/photo-1516571748831-5d81767b788d',
/// );
class SmartImage extends StatefulWidget {
  const SmartImage({
    super.key,
    this.size,
    required this.url,
    this.color,
  });

  final String? size;
  final String? url;
  final Color? color;

  @override
  State<SmartImage> createState() => _SmartImageState();
}

class _SmartImageState extends State<SmartImage> {
  Timer? _timer;
  int width = 0;
  int height = 0;
  double devicePixelRatio = 1;
  int resizedTimes = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(SmartImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      width = 0;
      height = 0;
      resizedTimes = 0;
      if (mounted) setState(() {});
    }
  }

  Future<void> _onChanged({int newHeight = 0, int newWidth = 0}) async {
    if (newHeight <= 0 && newWidth <= 0) return;
    await Future.delayed(const Duration(seconds: 2));
    if (width == newWidth && height == newHeight) return;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (width == newWidth && height == newHeight) return;
      if (newHeight > 0) height = newHeight;
      if (newWidth > 0) width = newWidth;
      resizedTimes++;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = widget.color ?? theme.colorScheme.surfaceVariant;
    Widget placeholderWidget = Container(color: background);

    /// Return placeholder image if path is not valid
    if (widget.url == null || widget.url!.isEmpty) {
      return placeholderWidget;
    }
    List<Widget> children = [
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final queryData = MediaQuery.of(context);
          devicePixelRatio = queryData.devicePixelRatio.floorToDouble();
          if (devicePixelRatio < 1) devicePixelRatio = 1;
          int newWidth = constraints.maxWidth.floor();
          int newHeight = constraints.maxHeight.floor();
          _onChanged(newHeight: newHeight, newWidth: newWidth);
          if (width <= 0 || height <= 0) {
            return placeholderWidget;
          }
          return SizedBox(
            width: newWidth.toDouble(),
            height: newHeight.toDouble(),
            // color: background,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.red,
                  width: 5,
                ),
              ),
            ),
          );
        },
      ),
    ];
    if (width <= 0 || height <= 0 || resizedTimes < 1) {
      children.add(placeholderWidget);
    } else {
      Map<String, List<String>> queryParameters = {};
      queryParameters.addAll({
        'dpr': [devicePixelRatio.toString()],
        'crop': ['entropy'],
      });
      if (widget.size != null) {
        queryParameters.addAll({
          'size': [widget.size.toString()],
        });
      } else {
        queryParameters.addAll({
          'width': [width.toString()],
          'height': [height.toString()],
        });
      }
      Uri uri = Uri.parse(widget.url!); //converts string to a uri
      String path = Utils.uriMergeQuery(
        uri: uri,
        queryParameters: queryParameters,
      ).toString();
      children.add(SizedBox.expand(
        child: Image.network(
          path,
          fit: BoxFit.cover,
          cacheWidth: width,
          cacheHeight: height,
          errorBuilder:
              (BuildContext context, Object exception, StackTrace? stackTrace) {
            return Container(
              color: theme.colorScheme.error,
              child: Center(
                child: Icon(
                  Icons.broken_image,
                  color: theme.colorScheme.onError,
                ),
              ),
            );
          },
          loadingBuilder: (BuildContext context, Widget child,
              ImageChunkEvent? loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            String pathPlaceholder = Utils.uriMergeQuery(
              uri: uri,
              queryParameters: {
                'width': [10.toString()],
                'height': [10.toString()],
              },
            ).toString();
            return SizedBox.expand(
              child: Image.network(pathPlaceholder, fit: BoxFit.fill),
            );
          },
          frameBuilder: (BuildContext context, Widget child, int? frame,
              bool wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) {
              return child;
            }
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(seconds: 1),
              curve: Curves.easeOut,
              child: child,
            );
          },
        ),
      ));
      // children.add(
      //   _image(
      //     width: width,
      //     height: height,
      //     url: widget.url!,
      //     devicePixelRatio: devicePixelRatio,
      //     size: widget.size,
      //   ),
      // );
    }
    return Stack(
      children: children,
    );
  }
}
