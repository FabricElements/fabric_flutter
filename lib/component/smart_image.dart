library fabric_flutter;

import 'dart:typed_data';

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
    Key? key,
    this.placeholder,
    this.size,
    required this.url,
    this.color = Colors.transparent,
  }) : super(key: key);
  final Uint8List? placeholder;
  final String? size;
  final String? url;
  final Color color;

  // FORMAT

  @override
  Widget build(BuildContext context) {
    final placeholderWidget = Container(color: color);

    /// Return placeholder image if path is not valid
    if (url == null || url!.isEmpty) {
      return placeholderWidget;
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final queryData = MediaQuery.of(context);
        double devicePixelRatio = queryData.devicePixelRatio;
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
        String path = Utils.uriQueryToStringPath(
          uri: uri,
          queryParameters: queryParameters,
        );
        return Container(
          color: color,
          child: Image.network(
            path,
            fit: BoxFit.cover,
            // colorBlendMode: BlendMode.srcATop,
            // color: color,
          ),
        );
      },
    );
  }
}
