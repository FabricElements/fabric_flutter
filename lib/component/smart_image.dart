import 'package:flutter/material.dart';

/// SmartImage can be used to display an image for basic Imgix or Internal implementation.
///
/// [url] This is the image url.
/// [size] Predefined sizes:
/// https://github.com/FabricElements/shared-helpers/blob/master/src/image-helper.ts#L17
///
/// SmartImage(
///   url: "https://images.unsplash.com/photo-1516571748831-5d81767b788d",
/// );
class SmartImage extends StatelessWidget {
  SmartImage({
    Key? key,
    required this.url,
    this.size,
  }) : super(key: key);
  final String url;
  final String? size;

  // FIT
  // AUTO
  // FORMAT
  // QUALITY
  // IMAGE LOCAL OR NETWORK

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final queryData = MediaQuery.of(context);
        double devicePixelRatio = queryData.devicePixelRatio;
        int width = constraints.maxWidth.floor();
        int height = constraints.maxHeight.floor();
        double biggest = constraints.biggest.longestSide;
        String resultUrl = "${this.url}?dpr=$devicePixelRatio&crop=entropy";
        if (size != null) {
          resultUrl += "&size=$size";
        } else {
          resultUrl += "&width=$width&height=$height";
        }
        return Image.network(
          resultUrl,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
