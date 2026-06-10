import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_network/image_network.dart';

import '../helper/utils.dart';

/// Enumerates the output formats supported by the backing image service.
enum AvailableOutputFormats {
  /// Requests AVIF output for modern browsers and compact transfers.
  avif,

  /// Requests Deep Zoom output for tiled image viewers.
  dz,

  /// Requests FITS output for compatible scientific imagery workflows.
  fits,

  /// Requests GIF output.
  gif,

  /// Requests HEIF output when the client can decode it.
  heif,

  /// Preserves the source format when the service supports passthrough output.
  input,

  /// Requests JPEG output for broad compatibility.
  jpeg,

  /// Requests JPEG 2000 output.
  jp2,

  /// Requests JPEG XL output.
  jxl,

  /// Requests ImageMagick-managed output.
  magick,

  /// Requests OpenSlide output for slide-imaging workflows.
  openslide,

  /// Requests PDF output.
  pdf,

  /// Requests PNG output for lossless transparency support.
  png,

  /// Requests PPM output.
  ppm,

  /// Requests raw pixel output.
  raw,

  /// Requests SVG output.
  svg,

  /// Requests TIFF output.
  tiff,

  /// Requests V format output when supported by the service.
  v,

  /// Requests WebP output for browsers that support it.
  webp,
}

/// Defines the named image sizes understood by the backing image service.
enum ImageSize {
  /// Requests a narrow thumbnail rendition, useful for previews and cards.
  thumbnail,

  /// Requests a compact square rendition for dense UI surfaces.
  small,

  /// Requests a medium rendition suitable for most inline media.
  medium,

  /// Requests a large standard rendition for detailed content views.
  standard,

  /// Requests a high-resolution rendition for larger displays.
  high,

  /// Requests the largest predefined rendition exposed by the service.
  max
}

/// Loads and resizes network images with sensible placeholders and responsive requests.
///
/// The widget measures its layout, debounces resize-driven URL changes, and then asks the
/// backing image service for an appropriately sized asset. That approach reduces wasted
/// bandwidth during rapid layout changes while still fitting naturally into Flutter's
/// rebuild lifecycle on mobile and web.
/// See https://github.com/FabricElements/shared-helpers/blob/main/src/media.ts.
///
/// Example:
/// ```dart
/// SmartImage(
///   url: 'https://images.unsplash.com/photo-1516571748831-5d81767b788d',
/// );
/// ```
class SmartImage extends StatefulWidget {
  /// Creates an adaptive network image widget for the supplied [url].
  const SmartImage({
    super.key,
    required this.url,
    this.size,
    this.color,
    this.format,
    this.fit = BoxFit.cover,
  });

  /// Identifies the source image to request, or shows a placeholder when absent.
  final String? url;

  /// Requests a predefined backend size instead of layout-derived dimensions.
  final ImageSize? size;

  /// Overrides the placeholder background color while the image is loading.
  final Color? color;

  /// Requests a specific backend output format for the generated image.
  final AvailableOutputFormats? format;

  /// Controls how the resolved image is inscribed into the available paint box.
  ///
  /// When [size] is omitted, this value also determines whether the widget requests both
  /// width and height from the backend or only a width-preserving resize.
  final BoxFit fit;

  /// Creates the state that measures layout changes and debounces resize requests.
  @override
  State<SmartImage> createState() => _SmartImageState();
}

/// Tracks measured dimensions and resolves the final image request URL.
class _SmartImageState extends State<SmartImage> {
  /// Debounces resize-triggered state updates so layout thrashing does not spam requests.
  Timer? _timer;
  /// Stores the debounced request width sent to the backend image service.
  int width = 0;
  /// Stores the debounced request height sent to the backend image service.
  int height = 0;
  /// Captures the current device pixel ratio so cache hints match display density.
  double devicePixelRatio = 1;
  /// Counts resize updates to lengthen the debounce after the initial measurement.
  int resizedTimes = 0;
  /// Remembers the actual layout width for widgets that need the rendered dimensions.
  double realWidth = 0;
  /// Remembers the actual layout height for widgets that need the rendered dimensions.
  double realHeight = 0;

  /// Cancels any pending resize debounce before the widget leaves the tree.
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Resets measured dimensions when the source image changes between rebuilds.
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

  /// Applies a newly measured request size when the dimensions actually changed.
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

  /// Defers resize updates to avoid issuing a new image request on every tiny layout tick.
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

  /// Builds placeholders first and swaps in the resolved network image when ready.
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
            return SizedBox.shrink();
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
          bool willCacheSize = widget.fit == BoxFit.fill;
          children.add(
            Positioned.fill(
              child: Image.network(
                path,
                fit: widget.fit,
                isAntiAlias: !kIsWeb,
                width: !willCacheSize ? null : width.toDouble(),
                height: !willCacheSize ? null : height.toDouble(),
                cacheHeight: !willCacheSize
                    ? null
                    : (height * devicePixelRatio).round(),
                cacheWidth: !willCacheSize
                    ? null
                    : (width * devicePixelRatio).round(),
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
