import 'package:google_maps_webservice/places.dart';
import 'package:json_annotation/json_annotation.dart';

part 'place_data.g.dart';

@JsonSerializable(explicitToJson: true)
class PlacesResponse extends GoogleResponseStatus {
  final List<Place> candidates;

  @JsonKey(name: 'html_attributions')
  final List<String> htmlAttributions;

  @JsonKey(name: 'next_page_token')
  final String? nextPageToken;

  @override
  @JsonKey(name: 'error_message')
  final String? errorMessage;

  PlacesResponse({
    required String status,
    this.errorMessage,
    this.candidates = const [],
    this.htmlAttributions = const [],
    this.nextPageToken,
  }) : super(status: status, errorMessage: errorMessage);

  factory PlacesResponse.fromJson(Map<String, dynamic>? json) =>
      _$PlacesResponseFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$PlacesResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class PlaceResponse {
  final Place? result;

  @JsonKey(name: 'html_attributions')
  final List<String> htmlAttributions;

  @override
  @JsonKey(name: 'error_message')
  final String? errorMessage;

  PlaceResponse({
    this.errorMessage,
    this.result,
    this.htmlAttributions = const [],
  }) : super();

  factory PlaceResponse.fromJson(Map<String, dynamic>? json) =>
      _$PlaceResponseFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$PlaceResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class PlusCode {
  @JsonKey(name: 'global_code')
  final String globalCode;

  @JsonKey(name: 'compound_code')
  final String? compoundCode;

  PlusCode({required this.globalCode, this.compoundCode});

  factory PlusCode.fromJson(Map<String, dynamic>? json) =>
      _$PlusCodeFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$PlusCodeToJson(this);
}

/// https://developers.google.com/maps/documentation/places/web-service/search-text#Place
@JsonSerializable(explicitToJson: true)
class Place {
  @JsonKey(name: 'plus_code')
  final PlusCode? plusCode;

  @JsonKey(name: 'place_id')
  final String placeId;

  final String? icon;
  final Geometry? geometry;
  final String name;

  @JsonKey(name: 'opening_hours')
  final OpeningHoursDetail? openingHours;

  final List<Photo> photos;

  final String? scope;

  @JsonKey(name: 'alt_ids')
  final List<AlternativeId> altIds;

  @JsonKey(name: 'price_level')
  final int? priceLevel;

  final num? rating;

  final List<String> types;

  final String? vicinity;

  @JsonKey(name: 'formatted_address')
  final String formattedAddress;

  @JsonKey(name: 'utc_offset')
  final num? utcOffset;

  /// JSON address_components
  @JsonKey(name: 'address_components', includeIfNull: false)
  List<AddressComponent>? addressComponents;

  Place({
    this.addressComponents,
    this.icon,
    this.geometry,
    this.openingHours,
    this.photos = const [],
    this.scope,
    this.altIds = const [],
    this.priceLevel,
    this.rating,
    this.types = const [],
    this.vicinity,
    required this.formattedAddress,
    this.plusCode,
    this.utcOffset,
    required this.name,
    required this.placeId,
  });

  factory Place.fromJson(Map<String, dynamic>? json) =>
      _$PlaceFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$PlaceToJson(this);
}
