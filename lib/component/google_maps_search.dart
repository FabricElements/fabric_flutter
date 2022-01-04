import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

import '../helper/alert_helper.dart';
import '../helper/app_localizations_delegate.dart';
import 'google_maps_preview.dart';

/// This view has a map and allow choose a specific location
///
/// [admin] determines if the current user is an admin
/// [signedIn] determines if the current user is signed In
/// [user] returns the user object
class GoogleMapsSearch extends StatefulWidget {
  GoogleMapsSearch({
    Key? key,
    required this.apiKey,
    this.mapType = MapType.normal,
    this.latitude,
    this.longitude,
    this.onChange,
    this.onError,
    this.placeId,
    this.name,
    this.fields = const [
      "formatted_address",
      "utc_offset",
    ],
    this.aspectRatio = 3 / 2,
  }) : super(key: key);
  final String? placeId;
  final Function(PlaceDetails)? onChange;
  final Function(String)? onError;
  final String apiKey;
  final double? latitude;
  final double? longitude;
  final MapType mapType;
  final String? name;
  final double aspectRatio;

  /// Define Google Places API fields you require on the response
  /// There is no need to include "name", "place_id", or "geometry/location"
  /// https://developers.google.com/maps/documentation/places/web-service/place-data-fields
  final List<String> fields;

  @override
  _GoogleMapsSearchState createState() => new _GoogleMapsSearchState();
}

class _GoogleMapsSearchState extends State<GoogleMapsSearch> {
  TextEditingController textController = TextEditingController();
  late GoogleMapsPlaces _places;

  int totalItems = 0;
  List<LatLng>? points;
  List<Widget>? listPlaces;
  late List<PlacesSearchResult> placesResults;
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
      List<String> _requiredFields = [
        "name",
        "place_id",
        "geometry/location",
      ];
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
      print(error);
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
    resetDefaultValues();
    getParentValues();
    loading = false;
    if (widget.placeId != null &&
        widget.latitude == null &&
        widget.longitude == null) {
      WidgetsBinding.instance?.addPostFrameCallback((_) {
        getPlaceById(id: widget.placeId!);
      });
    }
    super.initState();
  }

  @override
  void didUpdateWidget(covariant GoogleMapsSearch oldWidget) {
    textController.text = "";
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
    } catch (error) {}
  }

  void selectLocation({
    required PlacesSearchResult placeResult,
    required BuildContext context,
  }) async {
    await getPlaceById(notify: true, id: placeResult.placeId);
    _closeKeyboard(context);

    /// Reset after
    totalItems = 0;
    placesResults = [];
    if (mounted) setState(() {});
    if (widget.onChange != null && placeDetails != null) {
      widget.onChange!(placeDetails!);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    AppLocalizations locales = AppLocalizations.of(context)!;
    AlertHelper alert = AlertHelper(
      context: context,
      mounted: mounted,
    );
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
        double width = constraints.maxWidth.floorToDouble();
        double height = constraints.maxHeight.floorToDouble();
        mapComponents.clear();
        mapComponents.addAll([
          SafeArea(
            child: Container(
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
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  hintText: name ?? locales.get("label--search"),
                  suffixIcon: Icon(Icons.search),
                  fillColor: Colors.white,
                ),
                onChanged: (val) async {
                  if (val.length < 2) {
                    placesResults = [];
                    totalItems = 0;
                    if (mounted) setState(() {});
                    return;
                  }
                  // searchAddr = "$val, USA";
                  searchAddr = "$val";
                  try {
                    PlacesSearchResponse places = await _places.searchByText(
                      searchAddr,
                      type:
                          "administrative_area_level_1,administrative_area_level_2,locality,postal_codes",
                    );
                    placesResults = places.results;
                    totalItems = places.results.length;
                    if (mounted) setState(() {});
                  } catch (error) {
                    print(error);
                    alert.show(
                        title: error.toString(), type: AlertType.warning);
                  }
                },
              ),
            ),
          ),
        ]);

        if (totalItems > 0) {
          mapComponents.add(
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
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
                      children: placesResults.map((e) {
                        final item = e;
                        String formattedAddress = item.formattedAddress ?? "";
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
                                    placeResult: item,
                                    context: context,
                                  );
                                },
                              ),
                              Divider(height: 1),
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
                padding: EdgeInsets.all(16.0),
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
