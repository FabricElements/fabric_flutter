import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'smart_image.dart';

/// GoogleMapsPreview component
/// Displays a google map using [latitude] and [longitude]
/// MapBasic(
///   latitude: 40.7813821,
///   longitude: -73.9785516,
/// ),
class GoogleMapsPreview extends StatefulWidget {
  const GoogleMapsPreview({
    super.key,
    this.mapType = MapType.normal,
    this.latitude,
    this.longitude,
    this.aspectRatio = 3 / 2,
    this.zoom = 8,
    this.minMaxZoomPreference = const MinMaxZoomPreference(5, 25),
    this.name,
    this.description,
    this.apiKey,
    this.asImage = false,
  });

  final MapType mapType;
  final double? latitude;
  final double? longitude;
  final double aspectRatio;
  final double zoom;
  final MinMaxZoomPreference minMaxZoomPreference;
  final String? name;
  final String? description;
  final String? apiKey;
  final bool asImage;

  @override
  State<GoogleMapsPreview> createState() => _GoogleMapsPreviewState();
}

class _GoogleMapsPreviewState extends State<GoogleMapsPreview> {
  double? latitude;
  double? longitude;
  String? name;
  String? description;

  void reset() {
    latitude = null;
    longitude = null;
    name = null;
    description = null;
  }

  void getLocation({bool notify = false}) {
    reset();
    if (mounted && notify) setState(() {});
    Future.delayed(const Duration(milliseconds: 100), () {
      latitude = widget.latitude;
      longitude = widget.longitude;
      name = widget.name;
      description = widget.description;
      if (mounted && notify) setState(() {});
    });
  }

  @override
  void initState() {
    latitude = widget.latitude;
    longitude = widget.longitude;
    name = widget.name;
    description = widget.description;
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
    final theme = Theme.of(context);
    bool isDarkTheme = theme.brightness == Brightness.dark;
    bool supported = kIsWeb;
    if (!kIsWeb) {
      supported = Platform.isIOS || Platform.isAndroid || kIsWeb;
    }
    if (longitude == null ||
        longitude == null ||
        (!supported && widget.apiKey == null)) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: const SmartImage(
          url: 'https://images.unsplash.com/photo-1476973422084-e0fa66ff9456',
        ),
      );
    }
    if (!supported || widget.asImage) {
      String imageUrl =
          'https://maps.googleapis.com/maps/api/staticmap?zoom=13&maptype=roadmap&key=${widget.apiKey}';
      imageUrl += '&markers=color:red%7C${widget.latitude},${widget.longitude}';
      if (isDarkTheme) {
        imageUrl +=
            '&style=element:geometry%7Ccolor:0x242f3e&style=element:labels.text.fill%7Ccolor:0x746855&style=element:labels.text.stroke%7Ccolor:0x242f3e&style=feature:administrative.locality%7Celement:labels.text.fill%7Ccolor:0xd59563&style=feature:poi%7Celement:labels.text.fill%7Ccolor:0xd59563&style=feature:poi.park%7Celement:geometry%7Ccolor:0x263c3f&style=feature:poi.park%7Celement:labels.text.fill%7Ccolor:0x6b9a76&style=feature:road%7Celement:geometry%7Ccolor:0x38414e&style=feature:road%7Celement:geometry.stroke%7Ccolor:0x212a37&style=feature:road%7Celement:labels.text.fill%7Ccolor:0x9ca5b3&style=feature:road.highway%7Celement:geometry%7Ccolor:0x746855&style=feature:road.highway%7Celement:geometry.stroke%7Ccolor:0x1f2835&style=feature:road.highway%7Celement:labels.text.fill%7Ccolor:0xf3d19c&style=feature:transit%7Celement:geometry%7Ccolor:0x2f3948&style=feature:transit.station%7Celement:labels.text.fill%7Ccolor:0xd59563&style=feature:water%7Celement:geometry%7Ccolor:0x17263c&style=feature:water%7Celement:labels.text.fill%7Ccolor:0x515c6d&style=feature:water%7Celement:labels.text.stroke%7Ccolor:0x17263c';
      }
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
          final widthBox = constraints.maxWidth.toInt();
          final heightBox = constraints.maxHeight.toInt();
          return SmartImage(
            url: imageUrl,
            size: '$widthBox' 'x' '$heightBox',
          );
        }),
      );
    }

    LatLng location = LatLng(latitude!, longitude!);
    Completer<GoogleMapController> controller = Completer();
    final CameraPosition kGooglePlex = CameraPosition(
      target: location,
      zoom: widget.zoom,
    );
    InfoWindow infoWindow = InfoWindow.noText;
    if (name != null || description != null) {
      infoWindow = InfoWindow(title: name, snippet: description);
    }
    final Marker marker = Marker(
      markerId: const MarkerId('map-preview'),
      position: location,
      infoWindow: infoWindow,
    );
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: GoogleMap(
        minMaxZoomPreference: widget.minMaxZoomPreference,
        liteModeEnabled: false,
        mapType: widget.mapType,
        initialCameraPosition: kGooglePlex,
        onMapCreated: (GoogleMapController c) {
          /// TODO: Set map style when implemented
          // GoogleMapController gmc = c;
          // gmc.setMapStyle([
          //   {
          //     "elementType": "geometry",
          //     "stylers": [
          //       {"color": "#242f3e"}
          //     ]
          //   },
          //   {
          //     "elementType": "labels.text.fill",
          //     "stylers": [
          //       {"color": "#746855"}
          //     ]
          //   },
          //   {
          //     "elementType": "labels.text.stroke",
          //     "stylers": [
          //       {"color": "#242f3e"}
          //     ]
          //   },
          //   {
          //     "featureType": "administrative.locality",
          //     "elementType": "labels.text.fill",
          //     "stylers": [
          //       {"color": "#d59563"}
          //     ]
          //   },
          //   {
          //     "featureType": "poi",
          //     "elementType": "labels.text.fill",
          //     "stylers": [
          //       {"color": "#d59563"}
          //     ]
          //   },
          //   {
          //     "featureType": "poi.park",
          //     "elementType": "geometry",
          //     "stylers": [
          //       {"color": "#263c3f"}
          //     ]
          //   },
          //   {
          //     "featureType": "poi.park",
          //     "elementType": "labels.text.fill",
          //     "stylers": [
          //       {"color": "#6b9a76"}
          //     ]
          //   },
          //   {
          //     "featureType": "road",
          //     "elementType": "geometry",
          //     "stylers": [
          //       {"color": "#38414e"}
          //     ]
          //   },
          //   {
          //     "featureType": "road",
          //     "elementType": "geometry.stroke",
          //     "stylers": [
          //       {"color": "#212a37"}
          //     ]
          //   },
          //   {
          //     "featureType": "road",
          //     "elementType": "labels.text.fill",
          //     "stylers": [
          //       {"color": "#9ca5b3"}
          //     ]
          //   },
          //   {
          //     "featureType": "road.highway",
          //     "elementType": "geometry",
          //     "stylers": [
          //       {"color": "#746855"}
          //     ]
          //   },
          //   {
          //     "featureType": "road.highway",
          //     "elementType": "geometry.stroke",
          //     "stylers": [
          //       {"color": "#1f2835"}
          //     ]
          //   },
          //   {
          //     "featureType": "road.highway",
          //     "elementType": "labels.text.fill",
          //     "stylers": [
          //       {"color": "#f3d19c"}
          //     ]
          //   },
          //   {
          //     "featureType": "transit",
          //     "elementType": "geometry",
          //     "stylers": [
          //       {"color": "#2f3948"}
          //     ]
          //   },
          //   {
          //     "featureType": "transit.station",
          //     "elementType": "labels.text.fill",
          //     "stylers": [
          //       {"color": "#d59563"}
          //     ]
          //   },
          //   {
          //     "featureType": "water",
          //     "elementType": "geometry",
          //     "stylers": [
          //       {"color": "#17263c"}
          //     ]
          //   },
          //   {
          //     "featureType": "water",
          //     "elementType": "labels.text.fill",
          //     "stylers": [
          //       {"color": "#515c6d"}
          //     ]
          //   },
          //   {
          //     "featureType": "water",
          //     "elementType": "labels.text.stroke",
          //     "stylers": [
          //       {"color": "#17263c"}
          //     ]
          //   }
          // ].toString());
          controller.complete(c);
        },
        markers: <Marker>{marker},
        myLocationButtonEnabled: false,
      ),
    );
  }
}
