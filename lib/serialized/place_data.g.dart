// GENERATED CODE - DO NOT MODIFY BY HAND

part of fabric_flutter;

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlacesResponse _$PlacesResponseFromJson(Map<String, dynamic> json) =>
    PlacesResponse(
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
      results: (json['results'] as List<dynamic>?)
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
      'status': instance.status,
      'results': instance.results.map((e) => e.toJson()).toList(),
      'html_attributions': instance.htmlAttributions,
      'next_page_token': instance.nextPageToken,
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

Place _$PlaceFromJson(Map<String, dynamic> json) => Place(
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
      formattedAddress: json['formatted_address'] as String?,
      permanentlyClosed: json['permanently_closed'] as bool? ?? false,
      id: json['id'] as String?,
      plusCode: json['plus_code'] == null
          ? null
          : PlusCode.fromJson(json['plus_code'] as Map<String, dynamic>?),
      utcOffset: json['utc_offset'] as num?,
      name: json['name'] as String,
      placeId: json['place_id'] as String,
      reference: json['reference'] as String,
    );

Map<String, dynamic> _$PlaceToJson(Place instance) => <String, dynamic>{
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
      'permanently_closed': instance.permanentlyClosed,
      'utc_offset': instance.utcOffset,
      'id': instance.id,
      'reference': instance.reference,
    };
