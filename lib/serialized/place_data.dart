import 'package:json_annotation/json_annotation.dart';

part 'place_data.g.dart';

/// Converts a Google Places weekday and `HHmm` time into a UTC [DateTime].
///
/// Google Places opening-hours periods separate the weekday from the time. This
/// helper rebuilds them into a concrete timestamp relative to the current week.
/// It throws an [ArgumentError] when [time] does not contain at least four
/// digits because shorter values cannot be parsed safely.
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

/// Stores a latitude and longitude pair from the Places API.
///
/// The dedicated type keeps coordinate serialization consistent across geometry
/// payloads and provides a stable string representation for API requests.
@JsonSerializable(explicitToJson: true)
class Location {
  /// Stores the latitude in degrees.
  final double lat;

  /// Stores the longitude in degrees.
  final double lng;

  /// Creates a serialized location.
  Location({required this.lat, required this.lng});

  /// Builds [Location] from JSON returned by the Places API.
  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);

  /// Converts this location into JSON.
  Map<String, dynamic> toJson() => _$LocationToJson(this);

  /// Returns the `lat,lng` representation expected by map query strings.
  @override
  String toString() => '$lat,$lng';
}

/// Stores the geometric metadata associated with a place.
///
/// Places responses may contain a precise point plus optional viewport and bounds
/// data that help the UI frame or validate a selected location.
@JsonSerializable(explicitToJson: true)
class Geometry {
  /// Stores the primary point location of the place.
  final Location location;

  /// Stores the accuracy or source classification for [location].
  @JsonKey(name: 'location_type')
  final String? locationType;

  /// Stores the recommended viewport for displaying the place.
  final Bounds? viewport;

  /// Stores the bounding region for the place when provided.
  final Bounds? bounds;

  /// Creates serialized geometry metadata.
  Geometry({
    required this.location,
    this.locationType,
    this.viewport,
    this.bounds,
  });

  /// Builds [Geometry] from Places API JSON.
  factory Geometry.fromJson(Map<String, dynamic> json) =>
      _$GeometryFromJson(json);

  /// Converts this geometry into JSON.
  Map<String, dynamic> toJson() => _$GeometryToJson(this);
}

/// Stores a northeast and southwest boundary pair.
///
/// Bounds are used by the Places API to describe map regions, viewports, and
/// search biasing areas in a transport-friendly format.
@JsonSerializable(explicitToJson: true)
class Bounds {
  /// Stores the northeast corner of the bounds.
  final Location northeast;

  /// Stores the southwest corner of the bounds.
  final Location southwest;

  /// Creates serialized map bounds.
  Bounds({required this.northeast, required this.southwest});

  /// Returns the pipe-delimited format accepted by several Google Maps APIs.
  @override
  String toString() =>
      '${northeast.lat},${northeast.lng}|${southwest.lat},${southwest.lng}';

  /// Builds [Bounds] from Places API JSON.
  factory Bounds.fromJson(Map<String, dynamic> json) => _$BoundsFromJson(json);

  /// Converts these bounds into JSON.
  Map<String, dynamic> toJson() => _$BoundsToJson(this);
}

/// Represents a Places API search response containing multiple candidates.
///
/// The model keeps both successful results and error metadata because Google may
/// return partial or retryable responses that the UI still needs to inspect.
@JsonSerializable(explicitToJson: true)
class PlacesResponse {
  /// Stores the candidate places returned by the search.
  final List<Place> candidates;

  /// Stores HTML attribution strings required by Google licensing terms.
  @JsonKey(name: 'html_attributions')
  final List<String> htmlAttributions;

  /// Stores the pagination token for retrieving the next page of results.
  @JsonKey(name: 'next_page_token')
  final String? nextPageToken;

  /// Stores a human-readable error message when the request fails.
  @JsonKey(name: 'error_message')
  final String? errorMessage;

  /// Stores the Places API status code for the request.
  final String status;

  /// Creates a serialized places search response.
  PlacesResponse({
    required this.status,
    this.errorMessage,
    this.candidates = const [],
    this.htmlAttributions = const [],
    this.nextPageToken,
  });

  /// Builds [PlacesResponse] from Places API JSON.
  ///
  /// A `null` payload is treated as empty input so callers can safely deserialize
  /// optional responses and inspect default collections.
  factory PlacesResponse.fromJson(Map<String, dynamic>? json) =>
      _$PlacesResponseFromJson(json ?? {});

  /// Converts this places response into JSON.
  Map<String, dynamic> toJson() => _$PlacesResponseToJson(this);
}

/// Represents a Places API detail response containing a single place.
///
/// This wrapper mirrors Google's response structure so detail lookups can share
/// the same parsing conventions as broader search responses.
@JsonSerializable(explicitToJson: true)
class PlaceResponse {
  /// Stores the resolved place details when the request succeeds.
  final Place? result;

  /// Stores HTML attribution strings required by Google licensing terms.
  @JsonKey(name: 'html_attributions')
  final List<String> htmlAttributions;

  /// Stores a human-readable error message when the request fails.
  @JsonKey(name: 'error_message')
  final String? errorMessage;

  /// Creates a serialized place detail response.
  PlaceResponse({
    this.errorMessage,
    this.result,
    this.htmlAttributions = const [],
  });

  /// Builds [PlaceResponse] from Places API JSON.
  ///
  /// A `null` payload is treated as empty input so optional detail responses can
  /// still be deserialized into a predictable object.
  factory PlaceResponse.fromJson(Map<String, dynamic>? json) =>
      _$PlaceResponseFromJson(json ?? {});

  /// Converts this place response into JSON.
  Map<String, dynamic> toJson() => _$PlaceResponseToJson(this);
}

/// Stores an Open Location Code associated with a place.
///
/// Plus codes provide a compact fallback location identifier when a conventional
/// street address is unavailable or incomplete.
@JsonSerializable(explicitToJson: true)
class PlusCode {
  /// Stores the global Open Location Code.
  @JsonKey(name: 'global_code')
  final String globalCode;

  /// Stores the shorter locality-aware code when available.
  @JsonKey(name: 'compound_code')
  final String? compoundCode;

  /// Creates a serialized plus code.
  PlusCode({required this.globalCode, this.compoundCode});

  /// Builds [PlusCode] from Places API JSON.
  factory PlusCode.fromJson(Map<String, dynamic>? json) =>
      _$PlusCodeFromJson(json ?? {});

  /// Converts this plus code into JSON.
  Map<String, dynamic> toJson() => _$PlusCodeToJson(this);
}

/// Stores opening-hours metadata for a place.
///
/// The Places API can return both a high-level `openNow` flag and detailed daily
/// periods, so this model preserves both summary and schedule information.
@JsonSerializable(explicitToJson: true)
class OpeningHoursDetail {
  /// Indicates whether the place is open at the time the response was generated.
  @JsonKey(defaultValue: false)
  final bool openNow;

  /// Stores the structured opening and closing periods.
  final List<OpeningHoursPeriod> periods;

  /// Stores human-readable weekday schedule strings.
  final List<String> weekdayText;

  /// Creates serialized opening-hours metadata.
  OpeningHoursDetail({
    this.openNow = false,
    this.periods = const <OpeningHoursPeriod>[],
    this.weekdayText = const <String>[],
  });

  /// Builds [OpeningHoursDetail] from Places API JSON.
  factory OpeningHoursDetail.fromJson(Map<String, dynamic> json) =>
      _$OpeningHoursDetailFromJson(json);

  /// Converts this opening-hours payload into JSON.
  Map<String, dynamic> toJson() => _$OpeningHoursDetailToJson(this);
}

/// Stores the day and time portion of an opening-hours period.
///
/// Google separates these values instead of returning a direct timestamp, so the
/// model exposes helpers for rebuilding a comparable [DateTime].
@JsonSerializable(explicitToJson: true)
class OpeningHoursPeriodDate {
  /// Stores the weekday number returned by Google Places.
  final int day;

  /// Stores the time as a four-digit `HHmm` string.
  final String time;

  /// Returns the period as a UTC [DateTime].
  @Deprecated('use `toDateTime()`')
  DateTime get dateTime => toDateTime();

  /// Converts [day] and [time] into a UTC [DateTime].
  ///
  /// The conversion uses [dayTimeToDateTime] so all Places opening-hours parsing
  /// follows the same interpretation rules.
  DateTime toDateTime() => dayTimeToDateTime(day, time);

  /// Creates a serialized period date entry.
  OpeningHoursPeriodDate({required this.day, required this.time});

  /// Builds [OpeningHoursPeriodDate] from Places API JSON.
  factory OpeningHoursPeriodDate.fromJson(Map<String, dynamic> json) =>
      _$OpeningHoursPeriodDateFromJson(json);

  /// Converts this period date into JSON.
  Map<String, dynamic> toJson() => _$OpeningHoursPeriodDateToJson(this);
}

/// Stores one opening and closing interval for a place.
///
/// Either boundary may be absent in exceptional API responses, so both fields are
/// nullable to preserve the original payload faithfully.
@JsonSerializable(explicitToJson: true)
class OpeningHoursPeriod {
  /// Stores when the place opens for this period.
  final OpeningHoursPeriodDate? open;

  /// Stores when the place closes for this period.
  final OpeningHoursPeriodDate? close;

  /// Creates a serialized opening-hours period.
  OpeningHoursPeriod({this.open, this.close});

  /// Builds [OpeningHoursPeriod] from Places API JSON.
  factory OpeningHoursPeriod.fromJson(Map<String, dynamic> json) =>
      _$OpeningHoursPeriodFromJson(json);

  /// Converts this period into JSON.
  Map<String, dynamic> toJson() => _$OpeningHoursPeriodToJson(this);
}

/// Stores photo metadata associated with a place.
///
/// The model captures the photo reference token and dimensions required to later
/// request the actual image from Google.
@JsonSerializable(explicitToJson: true)
class Photo {
  /// Stores the token used to request the photo asset.
  @JsonKey(name: 'photo_reference')
  final String photoReference;

  /// Stores the original photo height.
  final num height;

  /// Stores the original photo width.
  final num width;

  /// Stores HTML attribution strings required by Google licensing terms.
  @JsonKey(name: 'html_attributions')
  final List<String> htmlAttributions;

  /// Creates serialized photo metadata.
  Photo({
    required this.photoReference,
    required this.height,
    required this.width,
    this.htmlAttributions = const <String>[],
  });

  /// Builds [Photo] from Places API JSON.
  factory Photo.fromJson(Map<String, dynamic> json) => _$PhotoFromJson(json);

  /// Converts this photo metadata into JSON.
  Map<String, dynamic> toJson() => _$PhotoToJson(this);
}

/// Stores an alternate identifier for a place.
///
/// Alternative IDs appear in some Places responses and help bridge a place to
/// older APIs or external systems that use different identifier scopes.
@JsonSerializable(explicitToJson: true)
class AlternativeId {
  /// Stores the alternate place identifier.
  @JsonKey(name: 'place_id')
  final String placeId;

  /// Stores the namespace or scope for [placeId].
  final String scope;

  /// Creates a serialized alternate identifier.
  AlternativeId({required this.placeId, required this.scope});

  /// Builds [AlternativeId] from Places API JSON.
  factory AlternativeId.fromJson(Map<String, dynamic> json) =>
      _$AlternativeIdFromJson(json);

  /// Converts this alternate identifier into JSON.
  Map<String, dynamic> toJson() => _$AlternativeIdToJson(this);
}

/// Stores one parsed address component from the Places API.
///
/// Address components let the application inspect specific pieces of an address,
/// such as locality or postal code, without reparsing the formatted string.
@JsonSerializable(explicitToJson: true)
class AddressComponent {
  /// Stores the component type identifiers supplied by Google.
  @JsonKey(defaultValue: <String>[])
  final List<String> types;

  /// Stores the long human-readable name for the component.
  @JsonKey(name: 'long_name')
  final String longName;

  /// Stores the abbreviated name for the component.
  @JsonKey(name: 'short_name')
  final String shortName;

  /// Creates a serialized address component.
  AddressComponent({
    required this.types,
    required this.longName,
    required this.shortName,
  });

  /// Builds [AddressComponent] from Places API JSON.
  factory AddressComponent.fromJson(Map<String, dynamic> json) =>
      _$AddressComponentFromJson(json);

  /// Converts this address component into JSON.
  Map<String, dynamic> toJson() => _$AddressComponentToJson(this);
}

/// Stores a Google Places place result.
///
/// This model mirrors the web-service payload closely so search and details data
/// can be cached or transported without losing provider-specific information.
/// See https://developers.google.com/maps/documentation/places/web-service/search-text#Place.
@JsonSerializable(explicitToJson: true)
class Place {
  /// Stores the plus code associated with the place when present.
  @JsonKey(name: 'plus_code')
  final PlusCode? plusCode;

  /// Stores the stable Google place identifier.
  @JsonKey(name: 'place_id')
  final String placeId;

  /// Stores the icon URL associated with the place type.
  final String? icon;

  /// Stores geometric metadata for the place.
  final Geometry? geometry;

  /// Stores the display name of the place.
  final String name;

  /// Stores opening-hours details when Google returns them.
  @JsonKey(name: 'opening_hours')
  final OpeningHoursDetail? openingHours;

  /// Stores the photo metadata returned for the place.
  final List<Photo> photos;

  /// Stores the provider-defined visibility scope when available.
  final String? scope;

  /// Stores alternate identifiers for legacy or scoped integrations.
  @JsonKey(name: 'alt_ids')
  final List<AlternativeId> altIds;

  /// Stores the relative price level when available.
  @JsonKey(name: 'price_level')
  final int? priceLevel;

  /// Stores the aggregate user rating when available.
  final num? rating;

  /// Stores provider-defined place type identifiers.
  final List<String> types;

  /// Stores a short vicinity description when provided.
  final String? vicinity;

  /// Stores the full formatted address for display and exports.
  @JsonKey(name: 'formatted_address')
  final String formattedAddress;

  /// Stores the UTC offset in minutes when available.
  @JsonKey(name: 'utc_offset')
  final int? utcOffset;

  /// Stores parsed address components when the response includes them.
  @JsonKey(name: 'address_components', includeIfNull: false)
  List<AddressComponent>? addressComponents;

  /// Creates a serialized place.
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

  /// Builds [Place] from Places API JSON.
  ///
  /// A `null` payload is treated as empty input so optional place responses can
  /// still be deserialized consistently.
  factory Place.fromJson(Map<String, dynamic>? json) =>
      _$PlaceFromJson(json ?? {});

  /// Converts this place into JSON.
  Map<String, dynamic> toJson() => _$PlaceToJson(this);
}
