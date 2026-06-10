import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'smart_image.dart';

/// Displays a geographic preview for the supplied coordinates.
///
/// The widget prefers an interactive [GoogleMap] when the current platform can
/// render it, but it falls back to a static image when native map support or
/// credentials are unavailable. This makes the widget safe to reuse in dialogs,
/// lists, and read-only detail screens.
///
/// ```dart
/// GoogleMapsPreview(
///   latitude: 40.7813821,
///   longitude: -73.9785516,
/// )
/// ```
class GoogleMapsPreview extends StatefulWidget {
  /// Creates a map preview for a single point of interest.
  ///
  /// The widget accepts optional coordinates, marker text, and a Google Static
  /// Maps API key so it can choose the most reliable preview mode for the
  /// current platform.
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

  /// Selects the visual rendering mode for the interactive map.
  final MapType mapType;

  /// Stores the latitude of the previewed location.
  final double? latitude;

  /// Stores the longitude of the previewed location.
  final double? longitude;

  /// Defines the width-to-height ratio used by the preview container.
  final double aspectRatio;

  /// Defines the initial camera zoom for the interactive map.
  final double zoom;

  /// Limits how far users can zoom when interaction is available.
  final MinMaxZoomPreference minMaxZoomPreference;

  /// Stores the marker title shown in the info window.
  final String? name;

  /// Stores the optional secondary text shown in the info window.
  final String? description;

  /// Stores the API key used for Google Static Maps fallback requests.
  final String? apiKey;

  /// Determines whether the widget always renders a static image.
  final bool asImage;

  /// Creates the mutable state used to cache preview data between rebuilds.
  ///
  /// The returned [_GoogleMapsPreviewState] mirrors incoming coordinates and
  /// marker text so asynchronous refreshes can be coordinated safely.
  @override
  State<GoogleMapsPreview> createState() => _GoogleMapsPreviewState();
}

/// Stores cached preview data across the widget lifecycle.
///
/// The state keeps a local copy of the current coordinates and marker text so
/// delayed refreshes can update the preview without mutating the widget.
class _GoogleMapsPreviewState extends State<GoogleMapsPreview> {
  /// Stores the latitude currently being rendered.
  double? latitude;

  /// Stores the longitude currently being rendered.
  double? longitude;

  /// Stores the current marker title.
  String? name;

  /// Stores the current marker description.
  String? description;

  /// Clears the cached preview data.
  ///
  /// Resetting these values before a refresh or disposal avoids temporarily
  /// displaying stale coordinates or marker metadata.
  void reset() {
    latitude = null;
    longitude = null;
    name = null;
    description = null;
  }

  /// Reloads cached preview data from the current widget.
  ///
  /// When `notify` is `true`, the method triggers rebuilds before and after the
  /// short delay so placeholder and fallback transitions stay aligned with the
  /// widget lifecycle.
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

  /// Seeds the cached preview data from the initial widget configuration.
  ///
  /// Initializing these values in [initState] ensures the first build can use
  /// the incoming coordinates immediately.
  @override
  void initState() {
    super.initState();
    latitude = widget.latitude;
    longitude = widget.longitude;
    name = widget.name;
    description = widget.description;
  }

  /// Clears cached preview data before the state is removed.
  ///
  /// Resetting local values helps prevent stale map data from lingering longer
  /// than the lifecycle of this [State].
  @override
  void dispose() {
    reset();
    super.dispose();
  }

  /// Refreshes cached preview data when the parent widget changes.
  ///
  /// The comparison against the stored coordinates avoids unnecessary delayed
  /// refreshes when unrelated widget properties update.
  @override
  void didUpdateWidget(covariant GoogleMapsPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.latitude != latitude || widget.longitude != longitude) {
      getLocation(notify: true);
    }
  }

  /// Builds the most appropriate preview for the current platform.
  ///
  /// The widget returns a placeholder image when coordinates are unavailable, a
  /// static map image when native map rendering is unsupported or image mode is
  /// forced, and an interactive [GoogleMap] otherwise for the current
  /// [BuildContext].
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
          format: AvailableOutputFormats.jpeg,
        ),
      );
    }
    if (!supported || widget.asImage) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final widthBox = constraints.maxWidth.toInt();
            final heightBox = constraints.maxHeight.toInt();
            String imageUrl =
                'https://maps.googleapis.com/maps/api/staticmap?zoom=13&maptype=roadmap&key=${widget.apiKey}';
            imageUrl +=
                '&markers=color:red%7C${widget.latitude},${widget.longitude}';
            if (isDarkTheme) {
              imageUrl +=
                  '&style=element:geometry%7Ccolor:0x242f3e&style=element:labels.text.fill%7Ccolor:0x746855&style=element:labels.text.stroke%7Ccolor:0x242f3e&style=feature:administrative.locality%7Celement:labels.text.fill%7Ccolor:0xd59563&style=feature:poi%7Celement:labels.text.fill%7Ccolor:0xd59563&style=feature:poi.park%7Celement:geometry%7Ccolor:0x263c3f&style=feature:poi.park%7Celement:labels.text.fill%7Ccolor:0x6b9a76&style=feature:road%7Celement:geometry%7Ccolor:0x38414e&style=feature:road%7Celement:geometry.stroke%7Ccolor:0x212a37&style=feature:road%7Celement:labels.text.fill%7Ccolor:0x9ca5b3&style=feature:road.highway%7Celement:geometry%7Ccolor:0x746855&style=feature:road.highway%7Celement:geometry.stroke%7Ccolor:0x1f2835&style=feature:road.highway%7Celement:labels.text.fill%7Ccolor:0xf3d19c&style=feature:transit%7Celement:geometry%7Ccolor:0x2f3948&style=feature:transit.station%7Celement:labels.text.fill%7Ccolor:0xd59563&style=feature:water%7Celement:geometry%7Ccolor:0x17263c&style=feature:water%7Celement:labels.text.fill%7Ccolor:0x515c6d&style=feature:water%7Celement:labels.text.stroke%7Ccolor:0x17263c';
            }
            imageUrl +=
                '&size=$widthBox'
                'x'
                '$heightBox';
            return SmartImage(url: imageUrl);
          },
        ),
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
          /// Defers custom map styling until the implementation is available.
          controller.complete(c);
        },
        markers: <Marker>{marker},
        myLocationButtonEnabled: false,
      ),
    );
  }
}
