import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_network/image_network.dart';

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
    this.fit = BoxFit.cover,
  });

  /// Image URL
  final String? url;

  /// Predefined sizes
  final ImageSize? size;

  /// Background color
  final Color? color;

  /// Output format
  final AvailableOutputFormats? format;

  /// How to inscribe the image into the space allocated during layout.
  ///
  /// The default varies based on the other fields. See the discussion at
  /// [paintImage].
  final BoxFit fit;

  @override
  State<SmartImage> createState() => _SmartImageState();
}

class _SmartImageState extends State<SmartImage> {
  Timer? _timer;
  int width = 0;
  int height = 0;
  double devicePixelRatio = 1;
  int resizedTimes = 0;
  double realWidth = 0;
  double realHeight = 0;

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
    _timer = Timer(Duration(milliseconds: resizedTimes > 0 ? 2000 : 300), () {
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
      Positioned.fill(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final queryData = MediaQuery.of(context);
            devicePixelRatio = queryData.devicePixelRatio.floorToDouble();
            if (devicePixelRatio < 1) devicePixelRatio = 1;
            realHeight = constraints.maxHeight;
            realWidth = constraints.maxWidth;

            /// Get dimensions in multiples of [divisor]
            /// This is to prevent too many requests do to small changes in dimensions
            int divisor =
                100; // Total pixels to divide by to get new dimensions
            int widthBasedOnDivisor = ((realWidth / divisor) * divisor).floor();
            int heightBasedOnDivisor = ((realHeight / divisor) * divisor)
                .floor();
            if (widthBasedOnDivisor < divisor) widthBasedOnDivisor = divisor;
            if (heightBasedOnDivisor < divisor) heightBasedOnDivisor = divisor;
            _resizeImageDebounce(
              newHeight: heightBasedOnDivisor,
              newWidth: widthBasedOnDivisor,
            );
            return loadingPlaceholder;
          },
        ),
      ),
    ];
    if (width > 0 && height > 0 && resizedTimes > 0) {
      Map<String, List<String>> queryParameters = {};
      queryParameters.addAll({
        'dpr': [devicePixelRatio.toString()],
      });
      if (widget.size != null) {
        queryParameters.addAll({
          'size': [widget.size!.name],
        });
      } else if (widget.fit == BoxFit.cover) {
        /// Crop to fit
        queryParameters.addAll({
          'width': [width.toString()],
          'height': [height.toString()],
          'crop': ['entropy'],
        });
      } else {
        /// Just resize but maintain aspect ratio
        queryParameters.addAll({
          'width': [width.toString()],
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
      /// Only load image if width and height are greater than 10
      if (width > 10 && height > 10 && resizedTimes > 0 && path.isNotEmpty) {
        if (!kIsWeb) {
          children.add(
            Positioned.fill(
              child: Image.network(
                path,
                fit: widget.fit,
                isAntiAlias: !kIsWeb,
                width: width.toDouble(),
                height: height.toDouble(),
                cacheHeight: (height * devicePixelRatio).round(),
                cacheWidth: (width * devicePixelRatio).round(),
                filterQuality: FilterQuality.high,
                key: ValueKey<String>(path),
                // This tells the browser to request the image with CORS headers
                // even though it's on the same domain.
                headers: {
                  'Access-Control-Allow-Origin': '*',
                  'Accept': 'image/*',
                },
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
        } else {
          late BoxFitWeb fitWeb;
          switch (widget.fit) {
            case BoxFit.contain:
              fitWeb = BoxFitWeb.contain;
              break;
            case BoxFit.fill:
              fitWeb = BoxFitWeb.fill;
              break;
            case BoxFit.none:
              fitWeb = BoxFitWeb.contain;
              break;
            case BoxFit.scaleDown:
              fitWeb = BoxFitWeb.contain;
              break;
            case BoxFit.cover:
              fitWeb = BoxFitWeb.cover;
              break;
            case BoxFit.fitHeight:
              fitWeb = BoxFitWeb.contain;
              break;
            case BoxFit.fitWidth:
              fitWeb = BoxFitWeb.contain;
              break;
            default:
              fitWeb = BoxFitWeb.cover;
          }
          children.add(
            Positioned.fill(
              child: IgnorePointer(
                child: ImageNetwork(
                  image: path,
                  width: realWidth,
                  height: realHeight,
                  key: ValueKey<String>(path),
                  onError: errorPlaceholder,
                  onLoading: loadingPlaceholder,
                  fitWeb: fitWeb,
                  fitAndroidIos: widget.fit,
                ),
              ),
            ),
          );
        }
      }
    }

    /// Return child with KeyedSubtree to avoid rebuild issues
    return KeyedSubtree(
      key: ValueKey('smart_image_${widget.url!}'),
      child: Stack(alignment: AlignmentDirectional.center, children: children),
    );
  }
}
