import 'package:flutter/material.dart';
import 'package:imgix/imgix.dart';

/// SmartImage utilizes Imgix to show an image.
///
/// [image] This is the image url.
/// SmartImage(
///   image: "https://images.unsplash.com/photo-1516571748831-5d81767b788d",
/// );
class SmartImgix extends StatelessWidget {
  SmartImgix({
    Key? key,
    required this.image,
  }) : super(key: key);
  final String image;

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
        double width = constraints.maxWidth;
        double height = constraints.maxHeight;
        String url = getImgixUrl(
          image,
          ImgixOptions(
              auto: [ImgixAuto.compress],
              format: ImgixFormat.jpg,
              height: height,
              quality: 75,
              width: width,
              devicePixelRatio: devicePixelRatio),
        );
        return Image.network(
          url,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
