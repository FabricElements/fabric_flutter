import 'package:json_annotation/json_annotation.dart';

part 'place_data.g.dart';

DateTime dayTimeToDateTime(int day, String time) {
  if (time.length < 4) {
    throw ArgumentError(
      "'time' is not a valid string. It must be four integers.",
    );
  }

  day = day == 0 ? DateTime.sunday : day;

  final now = DateTime.now();
  final mondayOfThisWeek = now.day - now.weekday;
  final computedWeekday = mondayOfThisWeek + day;

  final hour = int.parse(time.substring(0, 2));
  final minute = int.parse(time.substring(2));

  return DateTime.utc(now.year, now.month, computedWeekday, hour, minute);
}

@JsonSerializable(explicitToJson: true)
class Location {
  final double lat;
  final double lng;

  Location({required this.lat, required this.lng});

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);

  Map<String, dynamic> toJson() => _$LocationToJson(this);

  @override
  String toString() => '$lat,$lng';
}

@JsonSerializable(explicitToJson: true)
class Geometry {
  final Location location;

  @JsonKey(name: 'location_type')
  final String? locationType;
  final Bounds? viewport;
  final Bounds? bounds;

  Geometry({
    required this.location,
    this.locationType,
    this.viewport,
    this.bounds,
  });

  factory Geometry.fromJson(Map<String, dynamic> json) =>
      _$GeometryFromJson(json);

  Map<String, dynamic> toJson() => _$GeometryToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Bounds {
  final Location northeast;
  final Location southwest;

  Bounds({required this.northeast, required this.southwest});

  @override
  String toString() =>
      '${northeast.lat},${northeast.lng}|${southwest.lat},${southwest.lng}';

  factory Bounds.fromJson(Map<String, dynamic> json) => _$BoundsFromJson(json);

  Map<String, dynamic> toJson() => _$BoundsToJson(this);
}

@JsonSerializable(explicitToJson: true)
class PlacesResponse {
  final List<Place> candidates;

  @JsonKey(name: 'html_attributions')
  final List<String> htmlAttributions;

  @JsonKey(name: 'next_page_token')
  final String? nextPageToken;

  @JsonKey(name: 'error_message')
  final String? errorMessage;

  final String status;

  PlacesResponse({
    required this.status,
    this.errorMessage,
    this.candidates = const [],
    this.htmlAttributions = const [],
    this.nextPageToken,
  });

  factory PlacesResponse.fromJson(Map<String, dynamic>? json) =>
      _$PlacesResponseFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$PlacesResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class PlaceResponse {
  final Place? result;
  @JsonKey(name: 'html_attributions')
  final List<String> htmlAttributions;
  @JsonKey(name: 'error_message')
  final String? errorMessage;

  PlaceResponse({
    this.errorMessage,
    this.result,
    this.htmlAttributions = const [],
  });

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

@JsonSerializable(explicitToJson: true)
class OpeningHoursDetail {
  @JsonKey(defaultValue: false)
  final bool openNow;
  final List<OpeningHoursPeriod> periods;
  final List<String> weekdayText;

  OpeningHoursDetail({
    this.openNow = false,
    this.periods = const <OpeningHoursPeriod>[],
    this.weekdayText = const <String>[],
  });

  factory OpeningHoursDetail.fromJson(Map<String, dynamic> json) =>
      _$OpeningHoursDetailFromJson(json);

  Map<String, dynamic> toJson() => _$OpeningHoursDetailToJson(this);
}

@JsonSerializable(explicitToJson: true)
class OpeningHoursPeriodDate {
  final int day;
  final String time;

  /// UTC Time
  @Deprecated('use `toDateTime()`')
  DateTime get dateTime => toDateTime();

  DateTime toDateTime() => dayTimeToDateTime(day, time);

  OpeningHoursPeriodDate({required this.day, required this.time});

  factory OpeningHoursPeriodDate.fromJson(Map<String, dynamic> json) =>
      _$OpeningHoursPeriodDateFromJson(json);

  Map<String, dynamic> toJson() => _$OpeningHoursPeriodDateToJson(this);
}

@JsonSerializable(explicitToJson: true)
class OpeningHoursPeriod {
  final OpeningHoursPeriodDate? open;
  final OpeningHoursPeriodDate? close;

  OpeningHoursPeriod({this.open, this.close});

  factory OpeningHoursPeriod.fromJson(Map<String, dynamic> json) =>
      _$OpeningHoursPeriodFromJson(json);

  Map<String, dynamic> toJson() => _$OpeningHoursPeriodToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Photo {
  @JsonKey(name: 'photo_reference')
  final String photoReference;
  final num height;
  final num width;
  @JsonKey(name: 'html_attributions')
  final List<String> htmlAttributions;

  Photo({
    required this.photoReference,
    required this.height,
    required this.width,
    this.htmlAttributions = const <String>[],
  });

  factory Photo.fromJson(Map<String, dynamic> json) => _$PhotoFromJson(json);

  Map<String, dynamic> toJson() => _$PhotoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AlternativeId {
  @JsonKey(name: 'place_id')
  final String placeId;

  final String scope;

  AlternativeId({required this.placeId, required this.scope});

  factory AlternativeId.fromJson(Map<String, dynamic> json) =>
      _$AlternativeIdFromJson(json);

  Map<String, dynamic> toJson() => _$AlternativeIdToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AddressComponent {
  @JsonKey(defaultValue: <String>[])
  final List<String> types;

  @JsonKey(name: 'long_name')
  final String longName;

  @JsonKey(name: 'short_name')
  final String shortName;

  AddressComponent({
    required this.types,
    required this.longName,
    required this.shortName,
  });

  factory AddressComponent.fromJson(Map<String, dynamic> json) =>
      _$AddressComponentFromJson(json);

  Map<String, dynamic> toJson() => _$AddressComponentToJson(this);
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
  final int? utcOffset;

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
