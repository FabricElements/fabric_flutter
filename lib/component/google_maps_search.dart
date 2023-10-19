import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../serialized/place_data.dart';
import '../helper/app_localizations_delegate.dart';
import '../helper/http_request.dart';
import '../state/state_alert.dart';
import 'google_maps_preview.dart';

/// This view has a map and allow choose a specific location
///
/// [admin] determines if the current user is an admin
/// [signedIn] determines if the current user is signed In
/// [user] returns the user object
class GoogleMapsSearch extends StatefulWidget {
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
  final Function(Place)? onChange;
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
  final String baseUrl;
  final bool autofocus;

  /// Recommended 'administrative_area_level_1,administrative_area_level_2,locality,postal_codes'
  final List<String> types;

  /// Define Google Places API fields you require on the response
  /// There is no need to include 'name', 'place_id', or 'geometry/location'
  /// https://developers.google.com/maps/documentation/places/web-service/place-data-fields
  final List<String> fields;

  @override
  State<GoogleMapsSearch> createState() => _GoogleMapsSearchState();
}

class _GoogleMapsSearchState extends State<GoogleMapsSearch> {
  TextEditingController textController = TextEditingController();
  int totalItems = 0;
  List<LatLng>? points;
  late List<Place> results;
  late List<Widget> mapComponents;
  String? name;
  late bool loading;
  double? latitude;
  double? longitude;
  List<String> searchFields = [
    'formatted_address',
    'name',
    'place_id',
  ];
  late List<String> requiredFields;

  void resetDefaultValues() {
    results = [];
    mapComponents = [];
    totalItems = 0;
    points = [];
    latitude = null;
    longitude = null;
    name = null;
  }

  void getParentValues() {
    latitude = widget.latitude;
    longitude = widget.longitude;
    name = widget.name;
  }

  /// Google Maps controller definition
  late GoogleMapController mapController;

  @override
  void initState() {
    resetDefaultValues();
    getParentValues();
    loading = false;
    requiredFields = [...searchFields, 'geometry/location', ...widget.fields];
    super.initState();
  }

  @override
  void didUpdateWidget(covariant GoogleMapsSearch oldWidget) {
    textController.text = '';
    getParentValues();
    if (mounted) setState(() {});
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locales = AppLocalizations.of(context)!;
    final alert = Provider.of<StateAlert>(context, listen: false);

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
      final placeResponse = PlaceResponse.fromJson(newData);
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
        alert.show(AlertData(
          title: error.toString(),
          type: AlertType.warning,
          duration: 5,
          clear: true,
        ));
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
                  try {
                    Map<String, dynamic>? queryParameters = {
                      'key': widget.apiKey,
                      'input': val,
                      'inputtype': 'textquery',
                      'type':
                          widget.types.isEmpty ? null : widget.types.join(','),
                      'fields': searchFields.join(',')
                    };
                    Uri url = Uri.parse(
                        '${widget.baseUrl}/place/findplacefromtext/json');
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
                    alert.show(AlertData(
                      title: error.toString(),
                      type: AlertType.warning,
                      duration: 5,
                      clear: true,
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
                        String formattedAddress = item.formattedAddress;
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
                                  selectLocation(item);

                                  /// Close keyboard
                                  FocusScope.of(context)
                                      .requestFocus(FocusNode());
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
          apiKey: widget.apiKey,
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
