import 'dart:async';

import 'package:fabric_flutter/component/smart_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// [GoogleMapsPreview] component
/// Displays a google map using [latitude] and [longitude]
/// MapBasic(
///   latitude: 40.7813821,
///   longitude: -73.9785516,
/// ),
class GoogleMapsPreview extends StatefulWidget {
  const GoogleMapsPreview({
    Key? key,
    this.latitude,
    this.longitude,
  }) : super(key: key);
  final double? latitude;
  final double? longitude;

  @override
  _GoogleMapsPreviewState createState() => _GoogleMapsPreviewState();
}

class _GoogleMapsPreviewState extends State<GoogleMapsPreview> {
  LatLng? location;
  double? _latitude;
  double? _longitude;

  void getLocation() {
    _latitude = widget.latitude;
    _longitude = widget.longitude;
    location = _latitude != null && _longitude != null
        ? new LatLng(_latitude!, _longitude!)
        : null;
  }

  @override
  void initState() {
    getLocation();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant GoogleMapsPreview oldWidget) {
    getLocation();
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (location == null || _longitude == null || _longitude == null) {
      return AspectRatio(
        aspectRatio: 16 / 7,
        child: SmartImage(
          url: "https://images.unsplash.com/photo-1476973422084-e0fa66ff9456",
        ),
      );
    }
    Completer<GoogleMapController> _controller = Completer();
    final CameraPosition _kGooglePlex = CameraPosition(
      target: location!,
      zoom: 8,
    );
    final Marker marker =
        Marker(markerId: MarkerId("demo"), position: location!);
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: GoogleMap(
        minMaxZoomPreference: MinMaxZoomPreference(8, 25),
        liteModeEnabled: false,
        mapType: MapType.hybrid,
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
