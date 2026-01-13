import 'dart:async';

import 'package:flutter/material.dart';

import '../helper/utils.dart';

/// Available Image Output Formats
enum AvailableOutputFormats {
  avif,
  dz,
  fits,
  gif,
  heif,
  input,
  jpeg,
  jp2,
  jxl,
  magick,
  openslide,
  pdf,
  png,
  ppm,
  raw,
  svg,
  tiff,
  v,
  webp,
}

/// Enum for predefined image sizes.
///
/// Each size corresponds to a specific dimension.
///
/// * `thumbnail` - thumbnail size 200x400
/// * `small` - small size 200x200
/// * `medium` - medium size 600x600
/// * `standard` - standard size 1200x1200
/// * `high` - high size 1400x1400
/// * `max` - max size 1600x1600
enum ImageSize { thumbnail, small, medium, standard, high, max }

/// SmartImage can be used to display an image for basic Imgix or Internal implementation.
///
/// [url] This is the image url.
/// [size] Predefined size
/// https://github.com/FabricElements/shared-helpers/blob/main/src/media.ts
/// SmartImage(
///   url: 'https://images.unsplash.com/photo-1516571748831-5d81767b788d',
/// );
class SmartImage extends StatefulWidget {
  const SmartImage({
    super.key,
    required this.url,
    this.size,
    this.color,
    this.format,
  });

  /// Image URL
  final String? url;

  /// Predefined sizes
  final ImageSize? size;

  /// Background color
  final Color? color;

  /// Output format
  final AvailableOutputFormats? format;

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
      if (mounted) {
        setState(() {
          width = 0;
          height = 0;
          resizedTimes = 0;
        });
      }
    }
  }

  /// Resize image
  /// [newHeight] New height
  /// [newWidth] New width
  void _resizeImage({int newHeight = 0, int newWidth = 0}) {
    if (width == newWidth && height == newHeight) return;
    if (mounted) {
      setState(() {
        if (newHeight > 0) height = newHeight;
        if (newWidth > 0) width = newWidth;
        resizedTimes++;
      });
    }
  }

  /// Resize image with debounce
  /// This function will resize the image with debounce to prevent too many requests
  /// [newHeight] New height
  /// [newWidth] New width
  Future<void> _resizeImageDebounce({
    int newHeight = 0,
    int newWidth = 0,
  }) async {
    if (newHeight <= 0 && newWidth <= 0) return;
    if (width == newWidth && height == newHeight) return;
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: resizedTimes > 0 ? 2000 : 500), () {
      _resizeImage(newHeight: newHeight, newWidth: newWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        widget.color ?? theme.colorScheme.surfaceContainerHighest;
    final iconColor = theme.colorScheme.onSurfaceVariant;
    final defaultPlaceholder = Container(
      width: double.infinity,
      height: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(child: Icon(Icons.image_not_supported, color: iconColor)),
    );

    /// Return placeholder image if path is not valid
    if (widget.url == null || widget.url!.isEmpty) {
      return defaultPlaceholder;
    }
    final errorPlaceholder = Container(
      width: double.infinity,
      height: double.infinity,
      color: theme.colorScheme.errorContainer,
      child: Center(
        child: Icon(
          Icons.broken_image,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
    final loadingPlaceholder = Container(
      width: double.infinity,
      height: double.infinity,
      color: background,
      child: Center(child: Icon(Icons.downloading, color: iconColor)),
    );
    Uri uri = Uri.parse(widget.url!);

    /// List of children
    List<Widget> children = [
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final queryData = MediaQuery.of(context);
          devicePixelRatio = queryData.devicePixelRatio.floorToDouble();
          if (devicePixelRatio < 1) devicePixelRatio = 1;
          int newWidth = constraints.maxWidth.floor();
          int newHeight = constraints.maxHeight.floor();

          /// Get dimensions in multiples of [divisor]
          /// This is to prevent too many requests do to small changes in dimensions
          int divisor = 100; // Total pixels to divide by to get new dimensions
          int widthBasedOnDivisor = (newWidth / divisor).floor() * divisor;
          int heightBasedOnDivisor = (newHeight / divisor).floor() * divisor;
          if (widthBasedOnDivisor < divisor) widthBasedOnDivisor = divisor;
          if (heightBasedOnDivisor < divisor) heightBasedOnDivisor = divisor;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (resizedTimes > 0) {
              _resizeImageDebounce(
                newHeight: heightBasedOnDivisor,
                newWidth: widthBasedOnDivisor,
              );
            } else {
              _resizeImage(
                newHeight: heightBasedOnDivisor,
                newWidth: widthBasedOnDivisor,
              );
            }
          });
          return loadingPlaceholder;
        },
      ),
    ];
    if (width > 0 && height > 0 && resizedTimes > 0) {
      Map<String, List<String>> queryParameters = {};
      queryParameters.addAll({
        'dpr': [devicePixelRatio.toString()],
        'crop': ['entropy'],
      });
      if (widget.size != null) {
        queryParameters.addAll({
          'size': [widget.size!.name],
        });
      } else {
        queryParameters.addAll({
          'width': [width.toString()],
          'height': [height.toString()],
        });
      }
      if (widget.format != null) {
        queryParameters.addAll({
          'format': [widget.format!.name.toString()],
          'fm': [widget.format!.name.toString()],
        });
      }

      String path = Utils.uriMergeQuery(
        uri: uri,
        queryParameters: queryParameters,
      ).toString();

      /// Image
      children.add(
        SizedBox.expand(
          child: Image.network(
            path,
            fit: BoxFit.cover,
            isAntiAlias: true,
            key: ValueKey<String>(path),
            errorBuilder:
                (
                  BuildContext context,
                  Object exception,
                  StackTrace? stackTrace,
                ) {
                  return errorPlaceholder;
                },
            loadingBuilder:
                (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? loadingProgress,
                ) {
                  if (loadingProgress == null) return child;
                  return loadingPlaceholder;
                },
            frameBuilder:
                (
                  BuildContext context,
                  Widget child,
                  int? frame,
                  bool wasSynchronouslyLoaded,
                ) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
          ),
        ),
      );
    }
    return Stack(children: children);
  }
}
