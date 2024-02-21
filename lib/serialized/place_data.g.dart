// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Location _$LocationFromJson(Map<String, dynamic> json) => Location(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );

Map<String, dynamic> _$LocationToJson(Location instance) => <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
    };

Geometry _$GeometryFromJson(Map<String, dynamic> json) => Geometry(
      location: Location.fromJson(json['location'] as Map<String, dynamic>),
      locationType: json['locationType'] as String?,
      viewport: json['viewport'] == null
          ? null
          : Bounds.fromJson(json['viewport'] as Map<String, dynamic>),
      bounds: json['bounds'] == null
          ? null
          : Bounds.fromJson(json['bounds'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$GeometryToJson(Geometry instance) => <String, dynamic>{
      'location': instance.location.toJson(),
      'locationType': instance.locationType,
      'viewport': instance.viewport?.toJson(),
      'bounds': instance.bounds?.toJson(),
    };

Bounds _$BoundsFromJson(Map<String, dynamic> json) => Bounds(
      northeast: Location.fromJson(json['northeast'] as Map<String, dynamic>),
      southwest: Location.fromJson(json['southwest'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BoundsToJson(Bounds instance) => <String, dynamic>{
      'northeast': instance.northeast.toJson(),
      'southwest': instance.southwest.toJson(),
    };

PlacesResponse _$PlacesResponseFromJson(Map<String, dynamic> json) =>
    PlacesResponse(
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
      candidates: (json['candidates'] as List<dynamic>?)
              ?.map((e) => Place.fromJson(e as Map<String, dynamic>?))
              .toList() ??
          const [],
      htmlAttributions: (json['html_attributions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      nextPageToken: json['next_page_token'] as String?,
    );

Map<String, dynamic> _$PlacesResponseToJson(PlacesResponse instance) =>
    <String, dynamic>{
      'candidates': instance.candidates.map((e) => e.toJson()).toList(),
      'html_attributions': instance.htmlAttributions,
      'next_page_token': instance.nextPageToken,
      'error_message': instance.errorMessage,
      'status': instance.status,
    };

PlaceResponse _$PlaceResponseFromJson(Map<String, dynamic> json) =>
    PlaceResponse(
      errorMessage: json['error_message'] as String?,
      result: json['result'] == null
          ? null
          : Place.fromJson(json['result'] as Map<String, dynamic>?),
      htmlAttributions: (json['html_attributions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PlaceResponseToJson(PlaceResponse instance) =>
    <String, dynamic>{
      'result': instance.result?.toJson(),
      'html_attributions': instance.htmlAttributions,
      'error_message': instance.errorMessage,
    };

PlusCode _$PlusCodeFromJson(Map<String, dynamic> json) => PlusCode(
      globalCode: json['global_code'] as String,
      compoundCode: json['compound_code'] as String?,
    );

Map<String, dynamic> _$PlusCodeToJson(PlusCode instance) => <String, dynamic>{
      'global_code': instance.globalCode,
      'compound_code': instance.compoundCode,
    };

OpeningHoursDetail _$OpeningHoursDetailFromJson(Map<String, dynamic> json) =>
    OpeningHoursDetail(
      openNow: json['openNow'] as bool? ?? false,
      periods: (json['periods'] as List<dynamic>?)
              ?.map(
                  (e) => OpeningHoursPeriod.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <OpeningHoursPeriod>[],
      weekdayText: (json['weekdayText'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$OpeningHoursDetailToJson(OpeningHoursDetail instance) =>
    <String, dynamic>{
      'openNow': instance.openNow,
      'periods': instance.periods.map((e) => e.toJson()).toList(),
      'weekdayText': instance.weekdayText,
    };

OpeningHoursPeriodDate _$OpeningHoursPeriodDateFromJson(
        Map<String, dynamic> json) =>
    OpeningHoursPeriodDate(
      day: json['day'] as int,
      time: json['time'] as String,
    );

Map<String, dynamic> _$OpeningHoursPeriodDateToJson(
        OpeningHoursPeriodDate instance) =>
    <String, dynamic>{
      'day': instance.day,
      'time': instance.time,
    };

OpeningHoursPeriod _$OpeningHoursPeriodFromJson(Map<String, dynamic> json) =>
    OpeningHoursPeriod(
      open: json['open'] == null
          ? null
          : OpeningHoursPeriodDate.fromJson(
              json['open'] as Map<String, dynamic>),
      close: json['close'] == null
          ? null
          : OpeningHoursPeriodDate.fromJson(
              json['close'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$OpeningHoursPeriodToJson(OpeningHoursPeriod instance) =>
    <String, dynamic>{
      'open': instance.open?.toJson(),
      'close': instance.close?.toJson(),
    };

Photo _$PhotoFromJson(Map<String, dynamic> json) => Photo(
      photoReference: json['photoReference'] as String,
      height: json['height'] as num,
      width: json['width'] as num,
      htmlAttributions: (json['htmlAttributions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$PhotoToJson(Photo instance) => <String, dynamic>{
      'photoReference': instance.photoReference,
      'height': instance.height,
      'width': instance.width,
      'htmlAttributions': instance.htmlAttributions,
    };

AlternativeId _$AlternativeIdFromJson(Map<String, dynamic> json) =>
    AlternativeId(
      placeId: json['placeId'] as String,
      scope: json['scope'] as String,
    );

Map<String, dynamic> _$AlternativeIdToJson(AlternativeId instance) =>
    <String, dynamic>{
      'placeId': instance.placeId,
      'scope': instance.scope,
    };

AddressComponent _$AddressComponentFromJson(Map<String, dynamic> json) =>
    AddressComponent(
      types:
          (json['types'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
      longName: json['longName'] as String,
      shortName: json['shortName'] as String,
    );

Map<String, dynamic> _$AddressComponentToJson(AddressComponent instance) =>
    <String, dynamic>{
      'types': instance.types,
      'longName': instance.longName,
      'shortName': instance.shortName,
    };

Place _$PlaceFromJson(Map<String, dynamic> json) => Place(
      addressComponents: (json['address_components'] as List<dynamic>?)
          ?.map((e) => AddressComponent.fromJson(e as Map<String, dynamic>))
          .toList(),
      icon: json['icon'] as String?,
      geometry: json['geometry'] == null
          ? null
          : Geometry.fromJson(json['geometry'] as Map<String, dynamic>),
      openingHours: json['opening_hours'] == null
          ? null
          : OpeningHoursDetail.fromJson(
              json['opening_hours'] as Map<String, dynamic>),
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => Photo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      scope: json['scope'] as String?,
      altIds: (json['alt_ids'] as List<dynamic>?)
              ?.map((e) => AlternativeId.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      priceLevel: json['price_level'] as int?,
      rating: json['rating'] as num?,
      types:
          (json['types'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      vicinity: json['vicinity'] as String?,
      formattedAddress: json['formatted_address'] as String,
      plusCode: json['plus_code'] == null
          ? null
          : PlusCode.fromJson(json['plus_code'] as Map<String, dynamic>?),
      utcOffset: json['utc_offset'] as int?,
      name: json['name'] as String,
      placeId: json['place_id'] as String,
    );

Map<String, dynamic> _$PlaceToJson(Place instance) {
  final val = <String, dynamic>{
    'plus_code': instance.plusCode?.toJson(),
    'place_id': instance.placeId,
    'icon': instance.icon,
    'geometry': instance.geometry?.toJson(),
    'name': instance.name,
    'opening_hours': instance.openingHours?.toJson(),
    'photos': instance.photos.map((e) => e.toJson()).toList(),
    'scope': instance.scope,
    'alt_ids': instance.altIds.map((e) => e.toJson()).toList(),
    'price_level': instance.priceLevel,
    'rating': instance.rating,
    'types': instance.types,
    'vicinity': instance.vicinity,
    'formatted_address': instance.formattedAddress,
    'utc_offset': instance.utcOffset,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('address_components',
      instance.addressComponents?.map((e) => e.toJson()).toList());
  return val;
}
