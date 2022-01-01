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
    this.placeId,
    this.onChange,
    required this.apiKey,
  }) : super(key: key);
  final String? placeId;
  final Function(PlaceDetails)? onChange;
  final String apiKey;

  @override
  _GoogleMapsSearchState createState() => new _GoogleMapsSearchState();
}

class _GoogleMapsSearchState extends State<GoogleMapsSearch> {
  TextEditingController textController = TextEditingController();
  late GoogleMapsPlaces _places;

  int? totalItems;
  List<LatLng>? points;
  List<Widget>? listPlaces;
  late List<PlacesSearchResult> placesResults;
  late List<Widget> mapComponents;
  String? placeIdBase;
  String? placeName;
  late String searchAddr;
  late bool loading;
  double? latitude;
  double? longitude;

  /// Google Maps controller definition
  late GoogleMapController mapController;

  void getPlaceById() async {
    latitude = null;
    longitude = null;
    listPlaces = [];
    placeName = null;
    placeIdBase = null;
    try {
      final placeDetails = await _places.getDetailsByPlaceId(widget.placeId!,
          fields: ["geometry/location", "name"]);
      latitude = placeDetails.result.geometry?.location.lat;
      longitude = placeDetails.result.geometry?.location.lng;
      placeName = placeDetails.result.name;
      placeIdBase = placeDetails.result.placeId;
      if (mounted) setState(() {});
    } catch (error) {
      print(error);
    }
  }

  @override
  void initState() {
    _places = GoogleMapsPlaces(
        apiKey: widget.apiKey,
        baseUrl: kIsWeb
            ? 'https://cors-anywhere.herokuapp.com/https://maps.googleapis.com/maps/api'
            : null);
    latitude = null;
    longitude = null;
    listPlaces = [];
    mapComponents = [];
    totalItems = 0;
    if (widget.placeId != null) {
      getPlaceById();
    }
    points = [];
    loading = false;
    placeName = null;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant GoogleMapsSearch oldWidget) {
    textController.text = "";
    if (widget.placeId != null && widget.placeId != placeIdBase) {
      latitude = null;
      longitude = null;
      placeIdBase = null;
      if (mounted) setState(() {});
      getPlaceById();
    }
    super.didUpdateWidget(oldWidget);
  }

  // LatLng? location;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    AppLocalizations locales = AppLocalizations.of(context)!;
    AlertHelper alert = AlertHelper(
      context: context,
      mounted: mounted,
    );
    void _closeKeyboard() {
      try {
        FocusScope.of(context).requestFocus(FocusNode());
      } catch (error) {}
    }

    mapComponents.clear();
    mapComponents.addAll([
      Container(
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
            hintText: placeName ?? locales.get("label--search"),
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
              alert.show(title: error.toString(), type: AlertType.warning);
            }
          },
        ),
      ),
    ]);
    void selectLocation(int index) {
      _closeKeyboard();
      final item = placesResults[index];
      Map<String, dynamic> asJson = item.toJson();
      placeName = item.name;
      latitude = item.geometry!.location.lat;
      longitude = item.geometry!.location.lng;
      Map<String, dynamic> _data = {
        "placeId": item.placeId,
        "geometry": {
          "location": item.geometry!.location.toJson(),
        },
        "name": item.name,
      };
      if (widget.onChange != null && widget.placeId != item.placeId) {
        PlaceDetails _place = new PlaceDetails.fromJson(_data);
        widget.onChange!(_place);
      }

      /// Reset after
      totalItems = 0;
      placesResults = [];
    }

    if (totalItems! > 0) {
      mapComponents.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: double.infinity,
              minHeight: 10,
              maxHeight: 300,
            ),
            child: Material(
              clipBehavior: Clip.hardEdge,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: ListView.builder(
                primary: false,
                itemCount: totalItems,
                itemBuilder: (BuildContext context, int index) {
                  final item = placesResults[index];
                  String formattedAddress = item.formattedAddress ?? "";
                  return Container(
                    color: Colors.grey.shade50,
                    child: Wrap(
                      children: <Widget>[
                        ListTile(
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
                            selectLocation(index);
                          },
                        ),
                        Divider(height: 1),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }
    Widget preview =
        GoogleMapsPreview(latitude: latitude, longitude: longitude);
    return Stack(
      children: <Widget>[
        preview,
        Positioned(
          top: 0,
          right: 0,
          left: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: mapComponents,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
