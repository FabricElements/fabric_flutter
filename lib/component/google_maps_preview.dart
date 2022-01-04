import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'smart_image.dart';

/// [GoogleMapsPreview] component
/// Displays a google map using [latitude] and [longitude]
/// MapBasic(
///   latitude: 40.7813821,
///   longitude: -73.9785516,
/// ),
class GoogleMapsPreview extends StatefulWidget {
  const GoogleMapsPreview({
    Key? key,
    this.mapType = MapType.normal,
    this.latitude,
    this.longitude,
    this.aspectRatio = 3 / 2,
  }) : super(key: key);
  final MapType mapType;
  final double? latitude;
  final double? longitude;
  final double aspectRatio;

  @override
  _GoogleMapsPreviewState createState() => _GoogleMapsPreviewState();
}

class _GoogleMapsPreviewState extends State<GoogleMapsPreview> {
  double? latitude;
  double? longitude;

  void reset() {
    latitude = null;
    longitude = null;
  }

  void getLocation({bool notify = false}) {
    reset();
    if (mounted && notify) setState(() {});
    Future.delayed(const Duration(milliseconds: 100), () {
      latitude = widget.latitude;
      longitude = widget.longitude;
      if (mounted && notify) setState(() {});
    });
  }

  @override
  void initState() {
    latitude = widget.latitude;
    longitude = widget.longitude;
    super.initState();
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GoogleMapsPreview oldWidget) {
    if (widget.latitude != latitude || widget.longitude != longitude) {
      getLocation(notify: true);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (longitude == null || longitude == null) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: SmartImage(
          url: "https://images.unsplash.com/photo-1476973422084-e0fa66ff9456",
        ),
      );
    }
    LatLng location = new LatLng(latitude!, longitude!);
    Completer<GoogleMapController> _controller = Completer();
    final CameraPosition _kGooglePlex = CameraPosition(
      target: location,
      zoom: 8,
    );
    final Marker marker =
        Marker(markerId: MarkerId("demo"), position: location);
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: GoogleMap(
        minMaxZoomPreference: MinMaxZoomPreference(5, 25),
        liteModeEnabled: false,
        mapType: widget.mapType,
        initialCameraPosition: _kGooglePlex,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        markers: <Marker>{marker},
        myLocationButtonEnabled: false,
      ),
    );
  }
}
