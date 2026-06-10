import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../serialized/place_data.dart';
import '../helper/app_localizations_delegate.dart';
import '../helper/http_request.dart';
import 'alert_data.dart';
import 'google_maps_preview.dart';

/// Combines place search with a live map preview so users can choose a location.
///
/// The widget keeps the text query, search results, and selected coordinates in state so
/// it can bridge asynchronous Google Places lookups with the Flutter widget lifecycle. It
/// is useful for address and place pickers where callers need structured [Place] data but
/// also want immediate geographic feedback before persisting the selection.
class GoogleMapsSearch extends StatefulWidget {
  /// Creates a Google Maps search surface backed by the provided Places API key.
  const GoogleMapsSearch({
    super.key,
    required this.apiKey,
    this.mapType = MapType.normal,
    this.latitude,
    this.longitude,
    this.onChange,
    this.onError,
    this.name,
    this.fields = const [],
    this.types = const [],
    this.aspectRatio = 3 / 2,
    this.zoom = 8,
    this.minMaxZoomPreference = const MinMaxZoomPreference(5, 25),
    this.description,
    this.baseUrl = 'https://maps.googleapis.com/maps/api',
    this.autofocus = false,
  });

  /// Receives the fully populated [Place] after the user selects a search result.
  final Function(Place)? onChange;
  /// Receives human-readable errors from search and detail lookups.
  final Function(String)? onError;
  /// Authenticates requests sent to the Google Places and Maps web services.
  final String apiKey;
  /// Seeds the preview map with an initial latitude before a new search selection.
  final double? latitude;
  /// Seeds the preview map with an initial longitude before a new search selection.
  final double? longitude;
  /// Chooses the base map presentation used by the embedded preview.
  final MapType mapType;
  /// Supplies the initial label shown in the search field and preview marker.
  final String? name;
  /// Fixes the overall map surface aspect ratio to fit surrounding layouts predictably.
  final double aspectRatio;
  /// Defines the initial zoom level applied to the preview map.
  final double zoom;
  /// Constrains how far users can zoom the preview map in either direction.
  final MinMaxZoomPreference minMaxZoomPreference;
  /// Reserves room for descriptive context associated with the selected place.
  final String? description;
  /// Overrides the Google Maps API base URL, which is useful for testing or proxying.
  final String baseUrl;
  /// Requests focus for the search field when the widget first appears.
  final bool autofocus;

  /// Narrows queries to supported Google Place types when provided.
  final List<String> types;

  /// Adds extra Google Places detail fields beyond the defaults required by this widget.
  ///
  /// Core identifiers and geometry fields are appended automatically so callers only need
  /// to request the domain-specific fields they intend to persist or display later.
  /// See https://developers.google.com/maps/documentation/places/web-service/place-data-fields.
  final List<String> fields;

  /// Creates the state that owns search text, result lists, and selected coordinates.
  @override
  State<GoogleMapsSearch> createState() => _GoogleMapsSearchState();
}

/// Handles place searching, result selection, and preview synchronization.
class _GoogleMapsSearchState extends State<GoogleMapsSearch> {
  /// Controls the search field text so it can be cleared after parent updates.
  TextEditingController textController = TextEditingController();
  /// Tracks how many autocomplete results are currently visible.
  int totalItems = 0;
  /// Reserves storage for map points if richer preview overlays are added later.
  List<LatLng>? points;
  /// Stores the current place suggestions returned by the text search request.
  late List<Place> results;
  /// Holds the overlay widgets layered on top of the map preview during build.
  late List<Widget> mapComponents;
  /// Mirrors the selected place name displayed in the field hint and preview.
  String? name;
  /// Tracks whether an asynchronous lookup is currently updating the selection.
  late bool loading;
  /// Stores the currently selected latitude shown by the preview map.
  double? latitude;
  /// Stores the currently selected longitude shown by the preview map.
  double? longitude;
  /// Defines the minimal fields required to render and resolve text search results.
  List<String> searchFields = ['formatted_address', 'name', 'place_id'];
  /// Combines mandatory fields with caller-provided detail fields for place lookups.
  late List<String> requiredFields;

  /// Clears transient search state so a new query starts from a known baseline.
  void resetDefaultValues() {
    results = [];
    mapComponents = [];
    totalItems = 0;
    points = [];
    latitude = null;
    longitude = null;
    name = null;
  }

  /// Copies incoming coordinates and labels from the parent widget into local state.
  void getParentValues() {
    latitude = widget.latitude;
    longitude = widget.longitude;
    name = widget.name;
  }

  /// References the underlying Google Map controller for future imperative map actions.
  late GoogleMapController mapController;

  /// Initializes local search state and the required Google Places field list.
  @override
  void initState() {
    super.initState();
    resetDefaultValues();
    getParentValues();
    loading = false;
    requiredFields = [...searchFields, 'geometry/location', ...widget.fields];
  }

  /// Resynchronizes the preview when parent-provided coordinates or labels change.
  @override
  void didUpdateWidget(covariant GoogleMapsSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    textController.text = '';
    getParentValues();
    if (mounted) setState(() {});
  }

  /// Builds the stacked map preview, search field, and optional result list overlay.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locales = AppLocalizations.of(context);

    /// Get place object by id
    getPlaceById(String placeId) async {
      Map<String, dynamic>? queryParameters = {
        'key': widget.apiKey,
        'type': widget.types.isEmpty ? null : widget.types.join(','),
        'fields': requiredFields.join(','),
        'place_id': placeId,
      };
      Uri url = Uri.parse('${widget.baseUrl}/place/details/json');
      url = url.replace(queryParameters: queryParameters);
      final response = await http.get(url);
      dynamic newData = HTTPRequest.response(response);
      if (newData != null) debugPrint('Place Response Data: $newData');
      final placeResponse = PlaceResponse.fromJson(newData);
      if (newData != null) {
        debugPrint(
          'Serialized PlaceResponse Data: ${jsonEncode(placeResponse.toJson())}',
        );
      }
      if (placeResponse.errorMessage != null) {
        throw placeResponse.errorMessage!;
      }
      latitude = placeResponse.result!.geometry?.location.lat;
      longitude = placeResponse.result!.geometry?.location.lng;
      if (mounted) setState(() {});
      if (widget.onChange != null && latitude != null && longitude != null) {
        widget.onChange!(placeResponse.result!);
      }
    }

    /// Select location
    void selectLocation(Place result) async {
      latitude = null;
      longitude = null;
      name = null;
      totalItems = 0;
      results = [];
      if (mounted) setState(() {});
      try {
        await getPlaceById(result.placeId);
      } catch (error) {
        alertData(
          context: context,
          title: error.toString(),
          type: AlertType.warning,
          duration: 5,
        );
        if (widget.onError != null) widget.onError!(error.toString());
      }
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          double width = constraints.maxWidth.floorToDouble();
          double height = constraints.maxHeight.floorToDouble();
          mapComponents.clear();
          mapComponents.addAll([
            SafeArea(
              child: SizedBox(
                height: 50,
                child: TextField(
                  controller: textController,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                    filled: true,
                    hintText: name ?? locales.get('label--search'),
                    suffixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (val) async {
                    if (val.length < 2) {
                      results = [];
                      totalItems = 0;
                      if (mounted) setState(() {});
                      return;
                    }
                    try {
                      Map<String, dynamic>? queryParameters = {
                        'key': widget.apiKey,
                        'input': val,
                        'inputtype': 'textquery',
                        'type': widget.types.isEmpty
                            ? null
                            : widget.types.join(','),
                        'fields': searchFields.join(','),
                      };
                      Uri url = Uri.parse(
                        '${widget.baseUrl}/place/findplacefromtext/json',
                      );
                      url = url.replace(queryParameters: queryParameters);
                      final response = await http.get(url);
                      dynamic newData = HTTPRequest.response(response);
                      final search = PlacesResponse.fromJson(newData);
                      if (search.errorMessage != null) {
                        throw search.errorMessage!;
                      }
                      results = search.candidates;
                      totalItems = results.length;
                      if (mounted) setState(() {});
                    } catch (error) {
                      alertData(
                        context: context,
                        title: error.toString(),
                        type: AlertType.warning,
                        duration: 5,
                      );
                    }
                  },
                ),
              ),
            ),
          ]);

          if (totalItems > 0) {
            mapComponents.add(
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Material(
                    clipBehavior: Clip.hardEdge,
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: width,
                        minHeight: height / 3,
                        maxHeight: height / 2,
                      ),
                      child: SingleChildScrollView(
                        child: Flex(
                          direction: Axis.vertical,
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(results.length, (index) {
                            final item = results[index];
                            String formattedAddress = item.formattedAddress;
                            return Flex(
                              direction: Axis.vertical,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.location_on,
                                    color: theme.colorScheme.secondary,
                                  ),
                                  title: Text(formattedAddress),
                                  trailing: Icon(
                                    Icons.arrow_forward,
                                    color: theme.colorScheme.primary,
                                  ),
                                  onTap: () {
                                    selectLocation(item);

                                    /// Close keyboard
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(FocusNode());
                                  },
                                ),
                                const Divider(height: 1),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          Widget preview = GoogleMapsPreview(
            latitude: latitude,
            longitude: longitude,
            mapType: widget.mapType,
            aspectRatio: widget.aspectRatio,
            minMaxZoomPreference: widget.minMaxZoomPreference,
            zoom: widget.zoom,
            name: name,
            apiKey: widget.apiKey,
          );

          return Stack(
            children: <Widget>[
              preview,
              Positioned(
                top: 16,
                right: 16,
                left: 16,
                bottom: 16,
                child: Flex(
                  direction: Axis.vertical,
                  mainAxisSize: MainAxisSize.min,
                  children: mapComponents,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
