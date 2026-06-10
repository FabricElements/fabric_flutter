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
/// The widget keeps the text query, search results, and selected coordinates in
/// state so it can bridge asynchronous Google Places lookups with the Flutter
/// widget lifecycle. It is useful for address and place pickers where callers
/// need structured [Place] data but also want immediate geographic feedback
/// before persisting the selection.
class GoogleMapsSearch extends StatefulWidget {
  /// Creates a Google Maps search surface backed by the provided Places API key.
  ///
  /// The widget starts from [latitude], [longitude], and [name] when they are
  /// supplied, then emits a populated [Place] through [onChange] after the user
  /// selects a result. [fields] extends the default Google Places response, and
  /// [types] narrows the search scope when Google supports those filters.
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
  ///
  /// The callback fires only after the place-details request succeeds and the
  /// returned geometry includes both latitude and longitude values.
  final Function(Place)? onChange;

  /// Receives human-readable errors from search and detail lookups.
  ///
  /// Callers can use the callback to surface failures outside the built-in alert
  /// shown by the widget.
  final Function(String)? onError;

  /// Authenticates requests sent to the Google Places and Maps web services.
  ///
  /// The value is forwarded to both the autocomplete search request and the
  /// follow-up place-details request.
  final String apiKey;

  /// Seeds the preview map with an initial latitude before a new search selection.
  ///
  /// The state copies this value whenever the parent rebuilds with updated
  /// coordinates.
  final double? latitude;

  /// Seeds the preview map with an initial longitude before a new search selection.
  ///
  /// The state copies this value whenever the parent rebuilds with updated
  /// coordinates.
  final double? longitude;

  /// Chooses the base map presentation used by the embedded preview.
  ///
  /// The same [MapType] is passed directly to [GoogleMapsPreview].
  final MapType mapType;

  /// Supplies the initial label shown in the search field and preview marker.
  ///
  /// The value is also restored when the parent updates the widget with a new
  /// selected place.
  final String? name;

  /// Fixes the overall map surface aspect ratio to fit surrounding layouts predictably.
  ///
  /// Keeping the preview and overlay in a single [AspectRatio] helps preserve a
  /// stable layout while search results appear and disappear.
  final double aspectRatio;

  /// Defines the initial zoom level applied to the preview map.
  ///
  /// The value is forwarded to [GoogleMapsPreview] each time the widget builds.
  final double zoom;

  /// Constrains how far users can zoom the preview map in either direction.
  ///
  /// The limits are delegated to [GoogleMapsPreview] so the embedded map respects
  /// the same interaction bounds as the search surface.
  final MinMaxZoomPreference minMaxZoomPreference;

  /// Reserves room for descriptive context associated with the selected place.
  ///
  /// The property is retained for callers that keep supplemental place metadata
  /// alongside the chosen coordinates.
  final String? description;

  /// Overrides the Google Maps API base URL, which is useful for testing or proxying.
  ///
  /// The default points at the public Google Maps web-service endpoint.
  final String baseUrl;

  /// Requests focus for the search field when the widget first appears.
  ///
  /// Setting the flag to `true` lets search-first flows open the keyboard
  /// immediately.
  final bool autofocus;

  /// Narrows queries to supported Google Place types when provided.
  ///
  /// The list is joined into the comma-separated format expected by the Google
  /// Places APIs.
  final List<String> types;

  /// Adds extra Google Places detail fields beyond the defaults required by this widget.
  ///
  /// Core identifiers and geometry fields are appended automatically so callers
  /// only need to request the domain-specific fields they intend to persist or
  /// display later. See
  /// https://developers.google.com/maps/documentation/places/web-service/place-data-fields.
  final List<String> fields;

  /// Creates the state that owns search text, result lists, and selected coordinates.
  ///
  /// The returned [_GoogleMapsSearchState] coordinates network requests with the
  /// visible search and map preview widgets.
  @override
  State<GoogleMapsSearch> createState() => _GoogleMapsSearchState();
}

/// Handles place searching, result selection, and preview synchronization.
///
/// The state keeps transient UI values local so [GoogleMapsSearch] can react to
/// parent updates while still coordinating asynchronous Google Places requests.
class _GoogleMapsSearchState extends State<GoogleMapsSearch> {
  /// Controls the search field text so it can be cleared after parent updates.
  ///
  /// Keeping a dedicated [TextEditingController] lets the state reset the field
  /// without recreating the surrounding widget tree.
  TextEditingController textController = TextEditingController();

  /// Tracks how many autocomplete results are currently visible.
  ///
  /// The count determines whether the overlayed result list should be rendered.
  int totalItems = 0;

  /// Reserves storage for map points if richer preview overlays are added later.
  ///
  /// The list is reset with the rest of the transient selection state.
  List<LatLng>? points;

  /// Stores the current place suggestions returned by the text search request.
  ///
  /// The list feeds the tappable result tiles shown above the map preview.
  late List<Place> results;

  /// Holds the overlay widgets layered on top of the map preview during build.
  ///
  /// Rebuilding the list each frame keeps the stack contents aligned with the
  /// latest search and selection state.
  late List<Widget> mapComponents;

  /// Mirrors the selected place name displayed in the field hint and preview.
  ///
  /// The value is cleared while a new selection is loading so stale labels are
  /// not shown.
  String? name;

  /// Tracks whether an asynchronous lookup is currently updating the selection.
  ///
  /// The flag is initialized for future loading-state affordances even though the
  /// current widget does not render it yet.
  late bool loading;

  /// Stores the currently selected latitude shown by the preview map.
  ///
  /// The value is populated from either the parent widget or a place-details
  /// lookup.
  double? latitude;

  /// Stores the currently selected longitude shown by the preview map.
  ///
  /// The value is populated from either the parent widget or a place-details
  /// lookup.
  double? longitude;

  /// Defines the minimal fields required to render and resolve text search results.
  ///
  /// These fields support the result list and also provide the place identifier
  /// needed for the follow-up details request.
  List<String> searchFields = ['formatted_address', 'name', 'place_id'];

  /// Combines mandatory fields with caller-provided detail fields for place lookups.
  ///
  /// The list is assembled in [initState] so every details request includes both
  /// geometry data and any extra fields requested by the parent widget.
  late List<String> requiredFields;

  /// Clears transient search state so a new query starts from a known baseline.
  ///
  /// Resetting the state prevents stale results or coordinates from appearing
  /// between searches.
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
  ///
  /// Synchronizing these values lets externally controlled selections appear in
  /// the preview without bypassing the widget's local search flow.
  void getParentValues() {
    latitude = widget.latitude;
    longitude = widget.longitude;
    name = widget.name;
  }

  /// References the underlying Google Map controller for future imperative map actions.
  ///
  /// The field remains available for extensions that need to animate or inspect
  /// the embedded map directly.
  late GoogleMapController mapController;

  /// Initializes local search state and the required Google Places field list.
  ///
  /// The setup establishes a predictable empty baseline before applying any
  /// values passed from the parent widget.
  @override
  void initState() {
    super.initState();
    resetDefaultValues();
    getParentValues();
    loading = false;
    requiredFields = [...searchFields, 'geometry/location', ...widget.fields];
  }

  /// Resynchronizes the preview when parent-provided coordinates or labels change.
  ///
  /// Clearing [textController] ensures stale query text does not remain visible
  /// after the parent replaces the current selection.
  @override
  void didUpdateWidget(covariant GoogleMapsSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    textController.text = '';
    getParentValues();
    if (mounted) setState(() {});
  }

  /// Builds the stacked map preview, search field, and optional result list overlay.
  ///
  /// The layout keeps [GoogleMapsPreview] as the visual base layer and adds the
  /// searchable overlay above it so users can refine a location without leaving
  /// the map context.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locales = AppLocalizations.of(context);

    /// Resolves a selected autocomplete result into a full [Place].
    ///
    /// The request asks for [requiredFields] so [widget.onChange] receives the
    /// data the caller expects in addition to the geometry used by the preview.
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

    /// Selects a result and refreshes the preview from the place-details API.
    ///
    /// Clearing the visible state first avoids showing stale coordinates while the
    /// follow-up request is still in flight.
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
