import 'package:google_maps_webservice/places.dart';
import 'package:json_annotation/json_annotation.dart';

part 'place_data.g.dart';

@JsonSerializable(explicitToJson: true)
class PlacesResponse extends GoogleResponseStatus {
  @JsonKey(defaultValue: [])
  final List<Place> results;

  @JsonKey(name: 'html_attributions', defaultValue: [])
  final List<String> htmlAttributions;

  @JsonKey(name: 'next_page_token')
  final String? nextPageToken;

  @override
  @JsonKey(name: 'error_message')
  final String? errorMessage;

  PlacesResponse({
    required String status,
    this.errorMessage,
    this.results = const [],
    this.htmlAttributions = const [],
    this.nextPageToken,
  }) : super(status: status, errorMessage: errorMessage);

  factory PlacesResponse.fromJson(Map<String, dynamic>? json) =>
      _$PlacesResponseFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$PlacesResponseToJson(this);
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

  @JsonKey(defaultValue: [])
  final List<Photo> photos;

  final String? scope;

  @JsonKey(name: 'alt_ids', defaultValue: [])
  final List<AlternativeId> altIds;

  @JsonKey(name: 'price_level')
  final int? priceLevel;

  final num? rating;

  @JsonKey(defaultValue: [])
  final List<String> types;

  final String? vicinity;

  @JsonKey(name: 'formatted_address')
  final String? formattedAddress;

  @JsonKey(name: 'permanently_closed', defaultValue: false)
  final bool permanentlyClosed;

  @JsonKey(name: 'utc_offset')
  final num? utcOffset;

  final String? id;

  final String reference;

  Place({
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
    this.formattedAddress,
    this.permanentlyClosed = false,
    this.id,
    this.plusCode,
    this.utcOffset,
    required this.name,
    required this.placeId,
    required this.reference,
  });

  factory Place.fromJson(Map<String, dynamic>? json) =>
      _$PlaceFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$PlaceToJson(this);
}
