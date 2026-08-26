import 'dart:async';
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
  ///
  /// The [debounceMilliseconds] parameter controls the delay before firing a
  /// text search request after the user stops typing. A value of 400 ms provides
  /// a good balance between responsiveness and quota conservation; increase it
  /// if rate-limiting occurs, or decrease it for snappier feedback in low-traffic
  /// scenarios. Set to 0 to disable debouncing (not recommended for production).
  ///
  /// The [minimumQueryLength] parameter skips search requests for input shorter
  /// than this many characters. The default is 1, preserving behavior for existing
  /// callers. Raise it to 2, 3, or higher to suppress searches on short queries
  /// like two-letter region codes (`NY`, `CA`, `DC`) or country codes (`UK`).
  /// Note: raising this value silently suppresses legitimate short queries.
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
    this.clientFactory = http.Client.new,
    this.debounceMilliseconds = 400,
    this.minimumQueryLength = 1,
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

  /// Creates the HTTP client used for Google Places requests.
  ///
  /// The state creates one client when mounted, reuses it for autocomplete and
  /// place-details requests, and closes it on disposal. The default creates a
  /// standard [http.Client], while callers may inject a custom transport.
  final http.Client Function() clientFactory;

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

  /// Controls the debounce delay (in milliseconds) before firing a search request
  /// after the user stops typing.
  ///
  /// The default is 400 ms, which balances responsiveness against quota usage.
  /// Set to 0 to disable debouncing (not recommended for production use).
  final int debounceMilliseconds;

  /// Skips search requests for queries shorter than this many characters.
  ///
  /// The default is 1 character, preserving behavior for existing callers.
  /// Increase to 2, 3, or higher to filter out short searches like two-letter
  /// region codes (`NY`, `CA`, `DC`) or country codes (`UK`). Note that raising
  /// this value silently suppresses legitimate short queries; callers should
  /// consider the domain and adjust carefully.
  final int minimumQueryLength;

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
  /// Sends autocomplete and place-details requests for this state lifecycle.
  ///
  /// The client is created once in [initState] and closed in [dispose].
  late final http.Client _httpClient;

  /// Debounces text input so a request fires only after the user stops typing.
  ///
  /// The timer is cancelled and replaced each time the user types, then fires
  /// after [widget.debounceMilliseconds] milliseconds of inactivity. This
  /// conserves quota and reduces server load.
  Timer? _debounceTimer;

  /// Tracks the most recent search request by a unique identifier so responses
  /// can be validated against out-of-order delivery.
  ///
  /// A timestamp is sufficient: if a newer search is initiated while an older
  /// one is in flight, the older response is ignored when it arrives.
  int _currentSearchId = 0;

  /// Caches the last query string sent to avoid duplicate requests for identical input.
  String? _lastSearchQuery;

  /// Tracks if we recently received HTTP 429 (rate limit) to avoid tight loops.
  ///
  /// When a 429 is seen, the widget does not retry immediately. The flag is
  /// cleared when the user submits a new query, allowing normal operation to resume.
  bool _rateLimited = false;

  /// Controls the search field text so it can be cleared after parent updates.
  ///
  /// Keeping a dedicated [TextEditingController] lets the state reset the field
  /// without recreating the surrounding widget tree.
  final TextEditingController textController = TextEditingController();

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
    _httpClient = widget.clientFactory();
    resetDefaultValues();
    getParentValues();
    loading = false;
    requiredFields = [...searchFields, 'geometry/location', ...widget.fields];
  }

  /// Releases owned resources when the widget is removed from the tree.
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _httpClient.close();
    textController.dispose();
    super.dispose();
  }

  /// Performs a text search for places matching the given query.
  ///
  /// This method is called after the debounce timer expires. It skips the request
  /// if: (1) the widget is unmounted, (2) the query is unchanged from the last
  /// successful search, (3) the query is too short, or (4) we are rate-limited.
  ///
  /// Out-of-order responses are handled by assigning each request a unique ID
  /// ([_currentSearchId]) and ignoring responses for superseded requests.
  ///
  /// HTTP 429 responses trigger a calm notification instead of a loud error alert,
  /// and the widget stops retrying until the user submits a new query.
  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    if (_rateLimited) {
      return;
    }

    if (query == _lastSearchQuery) {
      return;
    }

    final searchId = ++_currentSearchId;

    try {
      Map<String, dynamic>? queryParameters = {
        'key': widget.apiKey,
        'input': query,
        'inputtype': 'textquery',
        'type': widget.types.isEmpty ? null : widget.types.join(','),
        'fields': searchFields.join(','),
      };
      Uri url = Uri.parse('${widget.baseUrl}/place/findplacefromtext/json');
      url = url.replace(queryParameters: queryParameters);
      final response = await _httpClient.get(url);

      if (response.statusCode == 429) {
        _rateLimited = true;
        if (mounted) {
          alertData(
            title:
                'Search temporarily unavailable. Please try again in a moment.',
            type: AlertType.basic,
            duration: 3,
          );
        }
        if (widget.onError != null) {
          widget.onError!('Rate limited');
        }
        return;
      }

      if (searchId != _currentSearchId) {
        return;
      }

      dynamic newData = HTTPRequest.response(response);
      final search = PlacesResponse.fromJson(newData);
      if (search.errorMessage != null) {
        throw search.errorMessage!;
      }

      if (searchId != _currentSearchId) {
        return;
      }

      _lastSearchQuery = query;
      results = search.candidates;
      totalItems = results.length;
      if (mounted) setState(() {});
    } catch (error) {
      if (searchId != _currentSearchId) {
        return;
      }

      alertData(title: error.toString(), type: AlertType.warning, duration: 5);
    }
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
      final response = await _httpClient.get(url);
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 50),
                child: Semantics(
                  textField: true,
                  label: locales.get('label--search-by-label', {
                    'label': locales.get('label--location'),
                  }),
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
                    onChanged: (val) {
                      _rateLimited = false;
                      _debounceTimer?.cancel();

                      if (val.length < widget.minimumQueryLength) {
                        results = [];
                        totalItems = 0;
                        if (mounted) setState(() {});
                        return;
                      }

                      _debounceTimer = Timer(
                        Duration(milliseconds: widget.debounceMilliseconds),
                        () => _performSearch(val),
                      );
                    },
                  ),
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
                                  leading: ExcludeSemantics(
                                    child: Icon(
                                      Icons.location_on,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                  title: Text(
                                    formattedAddress,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                  trailing: ExcludeSemantics(
                                    child: Icon(
                                      Icons.arrow_forward,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  onTap: () {
                                    selectLocation(item);
                                    FocusScope.of(context).unfocus();
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
