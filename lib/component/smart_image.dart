import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:transparent_image/transparent_image.dart';

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
  }) : super(key: key);
  final Uint8List? placeholder;
  final String? size;
  final String url;

  // FORMAT

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final queryData = MediaQuery.of(context);
        double devicePixelRatio = queryData.devicePixelRatio;
        int width = constraints.maxWidth.floor();
        int height = constraints.maxHeight.floor();
        // double biggest = constraints.biggest.longestSide;
        Uri uri = Uri.parse(url); //converts string to a uri
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
        return FadeInImage.memoryNetwork(
          fit: BoxFit.cover,
          image: path,
          placeholder: placeholder ?? kTransparentImage,
        );
      },
    );
  }
}
