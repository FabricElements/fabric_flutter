import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/geocoding.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../state/state_alert.dart';
import 'google_maps_preview.dart';

/// This view has a map and allow choose a specific location
///
/// [admin] determines if the current user is an admin
/// [signedIn] determines if the current user is signed In
/// [user] returns the user object
class GoogleMapsSearchGeocode extends StatefulWidget {
  const GoogleMapsSearchGeocode({
    Key? key,
    required this.apiKey,
    this.mapType = MapType.normal,
    this.latitude,
    this.longitude,
    this.onChange,
    this.onError,
    this.placeId,
    this.name,
    this.fields = const ['formatted_address', 'utc_offset'],
    this.aspectRatio = 3 / 2,
    this.zoom = 8,
    this.minMaxZoomPreference = const MinMaxZoomPreference(5, 25),
    this.description,
  }) : super(key: key);
  final String? placeId;
  final Function(GeocodingResult)? onChange;
  final Function(String)? onError;
  final String apiKey;
  final double? latitude;
  final double? longitude;
  final MapType mapType;
  final String? name;
  final double aspectRatio;
  final double zoom;
  final MinMaxZoomPreference minMaxZoomPreference;
  final String? description;

  /// Define Google Places API fields you require on the response
  /// There is no need to include 'name', 'place_id', or 'geometry/location'
  /// https://developers.google.com/maps/documentation/places/web-service/place-data-fields
  final List<String> fields;

  @override
  _GoogleMapsSearchGeocodeState createState() =>
      _GoogleMapsSearchGeocodeState();
}

class _GoogleMapsSearchGeocodeState extends State<GoogleMapsSearchGeocode> {
  TextEditingController textController = TextEditingController();
  late GoogleMapsPlaces _places;
  late GoogleMapsGeocoding _geocoding;

  int totalItems = 0;
  List<LatLng>? points;
  List<Widget>? listPlaces;
  late List<GeocodingResult> results;
  late List<Widget> mapComponents;
  String? placeId;
  String? name;
  late String searchAddr;
  late bool loading;
  double? latitude;
  double? longitude;
  PlaceDetails? placeDetails;

  void resetDefaultValues() {
    listPlaces = [];
    mapComponents = [];
    totalItems = 0;
    points = [];
    latitude = null;
    longitude = null;
    name = null;
    placeId = null;
    placeDetails = null;
  }

  void getParentValues() {
    latitude = widget.latitude;
    longitude = widget.longitude;
    name = widget.name;
    placeId = widget.placeId;
  }

  /// Google Maps controller definition
  late GoogleMapController mapController;

  Future<bool> getPlaceById({bool notify = false, required String id}) async {
    placeDetails = null;
    latitude = null;
    longitude = null;
    listPlaces = [];
    name = null;
    placeId = null;
    if (mounted) setState(() {});
    try {
      List<String> _requiredFields = ['name', 'place_id', 'geometry/location'];
      _requiredFields.addAll(widget.fields);
      final placeDetailsResponse =
          await _places.getDetailsByPlaceId(id, fields: _requiredFields);
      placeDetails = placeDetailsResponse.result;
      latitude = placeDetails!.geometry?.location.lat;
      longitude = placeDetails!.geometry?.location.lng;
      name = placeDetails!.formattedAddress ?? placeDetails!.name;
      placeId = placeDetails!.placeId;
      if (mounted) setState(() {});
      return true;
    } catch (error) {
      if (mounted) setState(() {});
      if (widget.onError != null) widget.onError!(error.toString());
    }
    return false;
  }

  @override
  void initState() {
    /// Temporal access at https://cors-anywhere.herokuapp.com/https://maps.googleapis.com/maps/ap
    _places = GoogleMapsPlaces(
        apiKey: widget.apiKey,
        baseUrl: kIsWeb
            ? 'https://cors-anywhere.herokuapp.com/https://maps.googleapis.com/maps/api'
            : null);
    _geocoding = GoogleMapsGeocoding(
        apiKey: widget.apiKey,
        baseUrl: kIsWeb
            ? 'https://cors-anywhere.herokuapp.com/https://maps.googleapis.com/maps/api'
            : null);
    resetDefaultValues();
    getParentValues();
    loading = false;
    if (widget.placeId != null &&
        widget.latitude == null &&
        widget.longitude == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        getPlaceById(id: widget.placeId!);
      });
    }
    super.initState();
  }

  @override
  void didUpdateWidget(covariant GoogleMapsSearchGeocode oldWidget) {
    textController.text = '';
    if (widget.placeId != placeId && widget.placeId != null) {
      getPlaceById(notify: true, id: widget.placeId!);
    } else {
      getParentValues();
    }
    if (mounted) setState(() {});
    super.didUpdateWidget(oldWidget);
  }

  /// Close keyboard
  void _closeKeyboard(BuildContext context) {
    try {
      FocusScope.of(context).requestFocus(FocusNode());
    } catch (error) {
      //
    }
  }

  void selectLocation({
    required GeocodingResult result,
    required BuildContext context,
  }) async {
    // await getPlaceById(notify: true, id: placeResult.placeId);

    placeDetails = null;
    latitude = null;
    longitude = null;
    listPlaces = [];
    name = null;
    placeId = null;
    if (mounted) setState(() {});
    try {
      latitude = result.geometry.location.lat;
      longitude = result.geometry.location.lng;
      name = result.formattedAddress;
      placeId = result.placeId;
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() {});
      if (widget.onError != null) widget.onError!(error.toString());
    }

    // === other

    _closeKeyboard(context);

    /// Reset after
    totalItems = 0;
    results = [];
    if (mounted) setState(() {});
    if (widget.onChange != null && latitude != null && longitude != null) {
      widget.onChange!(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    AppLocalizations locales = AppLocalizations.of(context)!;
    final alert = Provider.of<StateAlert>(context, listen: false);
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
                autofocus: true,
                keyboardType: TextInputType.text,
                keyboardAppearance: Brightness.light,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  filled: true,
                  hintText: name ?? locales.get('label--search'),
                  suffixIcon: const Icon(Icons.search),
                  fillColor: Colors.white,
                ),
                onChanged: (val) async {
                  if (val.length < 2) {
                    results = [];
                    totalItems = 0;
                    if (mounted) setState(() {});
                    return;
                  }
                  searchAddr = val;
                  try {
                    final search = await _geocoding.searchByAddress(searchAddr);
                    // PlacesSearchResponse places = await _places.searchByText(
                    //   searchAddr,
                    //   type:
                    //       'administrative_area_level_1,administrative_area_level_2,locality,postal_codes',
                    // );
                    results = search.results;
                    totalItems = search.results.length;
                    if (mounted) setState(() {});
                  } catch (error) {
                    alert.show(AlertData(
                      title: error.toString(),
                      type: AlertType.warning,
                    ));
                  }
                },
              ),
            ),
          ),
        ]);

        if (totalItems > 0) {
          mapComponents.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Material(
                clipBehavior: Clip.hardEdge,
                color: Colors.transparent,
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
                      children: results.map((e) {
                        final item = e;
                        String formattedAddress = item.formattedAddress ?? '';
                        return Container(
                          color: Colors.grey.shade50,
                          child: Wrap(
                            children: <Widget>[
                              ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.location_on,
                                  color: theme.colorScheme.primary,
                                ),
                                title: Text(formattedAddress),
                                trailing: Icon(
                                  Icons.arrow_forward,
                                  color: theme.colorScheme.primary,
                                ),
                                onTap: () {
                                  selectLocation(
                                    result: item,
                                    context: context,
                                  );
                                },
                              ),
                              const Divider(height: 1),
                            ],
                          ),
                        );
                      }).toList(),
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
        );

        return Stack(
          children: <Widget>[
            preview,
            Positioned(
              top: 0,
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Flex(
                  direction: Axis.vertical,
                  children: mapComponents,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
