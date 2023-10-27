import 'package:flutter/material.dart';

// import 'package:transparent_image/transparent_image.dart';

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
class SmartImage extends StatelessWidget {
  const SmartImage({
    super.key,
    this.size,
    required this.url,
    this.color,
  });

  final String? size;
  final String? url;
  final Color? color;

  // FORMAT

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = color ?? theme.colorScheme.surfaceVariant;
    Widget placeholderWidget = Container(color: background);

    /// Return placeholder image if path is not valid
    if (url == null || url!.isEmpty) {
      return placeholderWidget;
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final queryData = MediaQuery.of(context);
        double devicePixelRatio = queryData.devicePixelRatio.floorToDouble();
        if (devicePixelRatio < 1) devicePixelRatio = 1;
        int divisor = 100;

        /// Get dimensions in multiples of [divisor]
        int width = (constraints.maxWidth.floor() / divisor).floor() * divisor;
        int height =
            (constraints.maxHeight.floor() / divisor).floor() * divisor;
        if (width < divisor) width = divisor;
        if (height < divisor) height = divisor;
        // double biggest = constraints.biggest.longestSide;
        Uri uri = Uri.parse(url!); //converts string to a uri
        Map<String, List<String>> queryParameters = {};
        queryParameters.addAll({
          'dpr': [devicePixelRatio.toString()],
          'crop': ['entropy'],
        });
        if (size != null) {
          queryParameters.addAll({
            'size': [size.toString()],
          });
        } else {
          queryParameters.addAll({
            'width': [width.toString()],
            'height': [height.toString()],
          });
        }
        String path = Utils.uriMergeQuery(
          uri: uri,
          queryParameters: queryParameters,
        ).toString();
        return Container(
          color: background,
          child: Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: (BuildContext context, Object exception,
                StackTrace? stackTrace) {
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
                  'width': [50.toString()],
                  'height': [50.toString()],
                },
              ).toString();
              return Image.network(pathPlaceholder, fit: BoxFit.fill);
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
        );
      },
    );
  }
}
