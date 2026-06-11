import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_network/image_network.dart';

import '../helper/utils.dart';

/// Enumerates the output formats supported by the backing image service.
enum AvailableOutputFormats {
  /// Requests AVIF output.
  ///
  /// Uses a modern compressed format when the client and service both support it.
  avif,

  /// Requests Deep Zoom output.
  ///
  /// Supports tiled viewers that progressively load large images.
  dz,

  /// Requests FITS output.
  ///
  /// Supports scientific imagery workflows that consume FITS assets.
  fits,

  /// Requests GIF output.
  ///
  /// Preserves an animated or broadly compatible raster format.
  gif,

  /// Requests HEIF output.
  ///
  /// Uses a high-efficiency format when the client can decode it.
  heif,

  /// Preserves the source output format.
  ///
  /// Allows the backend to keep the input encoding when passthrough is available.
  input,

  /// Requests JPEG output.
  ///
  /// Favors wide compatibility for photographic imagery.
  jpeg,

  /// Requests JPEG 2000 output.
  ///
  /// Supports clients and workflows that depend on JP2 assets.
  jp2,

  /// Requests JPEG XL output.
  ///
  /// Uses a modern still-image format when supported by the pipeline.
  jxl,

  /// Requests ImageMagick-managed output.
  ///
  /// Defers to a service-specific format option exposed by ImageMagick.
  magick,

  /// Requests OpenSlide output.
  ///
  /// Supports slide-imaging workflows that consume OpenSlide data.
  openslide,

  /// Requests PDF output.
  ///
  /// Produces a document-friendly asset when the service supports it.
  pdf,

  /// Requests PNG output.
  ///
  /// Preserves lossless pixels and transparency.
  png,

  /// Requests PPM output.
  ///
  /// Supports workflows that expect raw portable pixmap images.
  ppm,

  /// Requests raw pixel output.
  ///
  /// Produces minimally processed pixel data when available.
  raw,

  /// Requests SVG output.
  ///
  /// Supports vector-friendly workflows when the source can be represented that way.
  svg,

  /// Requests TIFF output.
  ///
  /// Supports high-fidelity or archival raster workflows.
  tiff,

  /// Requests V format output.
  ///
  /// Uses a service-specific option when the backend exposes that format.
  v,

  /// Requests WebP output.
  ///
  /// Balances compression and browser support for modern clients.
  webp,
}

/// Defines the named image sizes understood by the backing image service.
enum ImageSize {
  /// Requests a thumbnail rendition.
  ///
  /// Favors compact previews and card layouts.
  thumbnail,

  /// Requests a small rendition.
  ///
  /// Fits dense interface surfaces that need a compact image.
  small,

  /// Requests a medium rendition.
  ///
  /// Covers most inline media placements.
  medium,

  /// Requests a standard rendition.
  ///
  /// Balances fidelity and transfer size for detailed views.
  standard,

  /// Requests a high-resolution rendition.
  ///
  /// Supports larger displays that need more detail.
  high,

  /// Requests the largest predefined rendition.
  ///
  /// Uses the maximum backend size exposed by the service.
  max,
}

/// Loads and resizes network images with sensible placeholders and responsive requests.
///
/// The widget measures its layout, debounces resize-driven URL changes, and then asks the
/// backing image service for an appropriately sized asset. That approach reduces wasted
/// bandwidth during rapid layout changes while still fitting naturally into Flutter's
/// rebuild lifecycle on mobile and web.
///
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
  ///
  /// Uses [size], [format], and [fit] to decide how the backend should transform the
  /// image before the widget paints it.
  const SmartImage({
    super.key,
    required this.url,
    this.size,
    this.color,
    this.format,
    this.fit = BoxFit.cover,
  });

  /// Identifies the source image to request.
  ///
  /// Shows the default placeholder when the value is `null` or empty.
  final String? url;

  /// Requests a predefined backend size.
  ///
  /// Overrides layout-derived dimensions when the service should use a named rendition.
  final ImageSize? size;

  /// Overrides the loading placeholder background color.
  ///
  /// Falls back to the current [ThemeData.colorScheme] when the value is `null`.
  final Color? color;

  /// Requests a specific backend output format.
  ///
  /// Leaves the service default in place when the value is `null`.
  final AvailableOutputFormats? format;

  /// Controls how the resolved image is inscribed into the available paint box.
  ///
  /// When [size] is omitted, this value also determines whether the widget requests both
  /// width and height from the backend or only a width-preserving resize.
  final BoxFit fit;

  /// Creates the state that measures layout changes and debounces resize requests.
  ///
  /// Returns a private [_SmartImageState] so the widget can track responsive image
  /// dimensions between rebuilds.
  @override
  State<SmartImage> createState() => _SmartImageState();
}

/// Tracks measured dimensions and resolves the final image request URL.
///
/// Stores layout-derived sizing data so the widget can avoid issuing a new request for every
/// transient size change.
class _SmartImageState extends State<SmartImage> {
  /// Debounces resize-triggered state updates.
  ///
  /// Prevents layout thrashing from issuing excessive backend image requests.
  Timer? _timer;

  /// Stores the debounced request width.
  ///
  /// Uses `0` until the widget has captured a meaningful layout width.
  int width = 0;

  /// Stores the debounced request height.
  ///
  /// Uses `0` until the widget has captured a meaningful layout height.
  int height = 0;

  /// Captures the current device pixel ratio.
  ///
  /// Keeps cache sizing aligned with the display density used for rendering.
  double devicePixelRatio = 1;

  /// Counts completed resize updates.
  ///
  /// Lengthens the debounce window after the initial image measurement settles.
  int resizedTimes = 0;

  /// Remembers the current layout width.
  ///
  /// Passes the rendered width to web-specific image widgets that need explicit dimensions.
  double realWidth = 0;

  /// Remembers the current layout height.
  ///
  /// Passes the rendered height to web-specific image widgets that need explicit dimensions.
  double realHeight = 0;

  /// Cancels any pending resize debounce before the widget leaves the tree.
  ///
  /// Releases the active [Timer] so delayed callbacks do not outlive the state object.
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Resets measured dimensions when the source image changes.
  ///
  /// Clears cached sizing so a new [SmartImage.url] triggers a fresh responsive request.
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

  /// Applies a newly measured request size when the dimensions changed.
  ///
  /// Ignores `0` values so partially known measurements do not erase a usable size.
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

  /// Defers resize updates to avoid repeated requests during layout churn.
  ///
  /// Uses a short initial debounce and then a longer debounce after the first settled
  /// measurement so resizing remains responsive without flooding the backend.
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
  ///
  /// Uses [BuildContext] to read theme and media-query data so the widget can choose
  /// placeholders, cache sizing, and platform-specific image widgets.
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
    final Uri uri = Uri.parse(widget.url!);

    final List<Widget> children = [
      Positioned.fill(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final queryData = MediaQuery.of(context);
            devicePixelRatio = queryData.devicePixelRatio.floorToDouble();
            if (devicePixelRatio < 1) devicePixelRatio = 1;
            realHeight = constraints.maxHeight;
            realWidth = constraints.maxWidth;

            int divisor = 100;
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
      final Map<String, List<String>> queryParameters = {};
      queryParameters.addAll({
        'dpr': [devicePixelRatio.toString()],
      });
      if (widget.size != null) {
        queryParameters.addAll({
          'size': [widget.size!.name],
        });
      } else if (widget.fit == BoxFit.cover) {
        queryParameters.addAll({
          'width': [width.toString()],
          'height': [height.toString()],
          'crop': ['entropy'],
        });
      } else {
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

      final String path = Utils.uriMergeQuery(
        uri: uri,
        queryParameters: queryParameters,
      ).toString();

      if (width > 10 && height > 10 && resizedTimes > 0 && path.isNotEmpty) {
        if (!kIsWeb) {
          final bool willCacheSize = widget.fit == BoxFit.fill;
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

    return KeyedSubtree(
      key: ValueKey('smart_image_${widget.url!}'),
      child: Stack(alignment: AlignmentDirectional.center, children: children),
    );
  }
}
