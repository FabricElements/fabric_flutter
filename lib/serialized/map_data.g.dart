// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MapLatLng _$MapLatLngFromJson(Map<String, dynamic> json) => MapLatLng(
  (json['latitude'] as num?)?.toDouble() ?? 0.0,
  (json['longitude'] as num?)?.toDouble() ?? 0.0,
);

Map<String, dynamic> _$MapLatLngToJson(MapLatLng instance) => <String, dynamic>{
  'latitude': instance.latitude,
  'longitude': instance.longitude,
};

MapMarker _$MapMarkerFromJson(Map<String, dynamic> json) => MapMarker(
  MapLatLng.fromJson(json['position'] as Map<String, dynamic>?),
  json['name'] as String? ?? '',
  json['description'] as String? ?? '',
);

Map<String, dynamic> _$MapMarkerToJson(MapMarker instance) => <String, dynamic>{
  'position': instance.position.toJson(),
  'name': instance.name,
  'description': instance.description,
};

MapCircle _$MapCircleFromJson(Map<String, dynamic> json) => MapCircle(
  MapLatLng.fromJson(json['center'] as Map<String, dynamic>?),
  (json['radius'] as num?)?.toDouble() ?? 0,
);

Map<String, dynamic> _$MapCircleToJson(MapCircle instance) => <String, dynamic>{
  'center': instance.center.toJson(),
  'radius': instance.radius,
};

MapPolygon _$MapPolygonFromJson(Map<String, dynamic> json) => MapPolygon(
  (json['points'] as List<dynamic>?)
          ?.map((e) => MapLatLng.fromJson(e as Map<String, dynamic>?))
          .toList() ??
      [],
  (json['holes'] as List<dynamic>?)
          ?.map(
            (e) =>
                (e as List<dynamic>)
                    .map((e) => MapLatLng.fromJson(e as Map<String, dynamic>?))
                    .toList(),
          )
          .toList() ??
      [],
);

Map<String, dynamic> _$MapPolygonToJson(MapPolygon instance) =>
    <String, dynamic>{
      'points': instance.points.map((e) => e.toJson()).toList(),
      'holes':
          instance.holes.map((e) => e.map((e) => e.toJson()).toList()).toList(),
    };

MapPolyline _$MapPolylineFromJson(Map<String, dynamic> json) => MapPolyline(
  (json['points'] as List<dynamic>?)
          ?.map((e) => MapLatLng.fromJson(e as Map<String, dynamic>?))
          .toList() ??
      [],
  (json['patterns'] as List<dynamic>?)
          ?.map((e) => MapPatternItem.fromJson(e as Map<String, dynamic>?))
          .toList() ??
      [],
);

Map<String, dynamic> _$MapPolylineToJson(MapPolyline instance) =>
    <String, dynamic>{
      'points': instance.points.map((e) => e.toJson()).toList(),
      'patterns': instance.patterns.map((e) => e.toJson()).toList(),
    };

MapPatternItem _$MapPatternItemFromJson(Map<String, dynamic> json) =>
    MapPatternItem(
      $enumDecodeNullable(_$MapPatternEnumMap, json['pattern']) ??
          MapPattern.dot,
      (json['length'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$MapPatternItemToJson(MapPatternItem instance) =>
    <String, dynamic>{
      'pattern': _$MapPatternEnumMap[instance.pattern]!,
      'length': instance.length,
    };

const _$MapPatternEnumMap = {
  MapPattern.dot: 'dot',
  MapPattern.dash: 'dash',
  MapPattern.gap: 'gap',
};

MapData _$MapDataFromJson(Map<String, dynamic> json) => MapData(
  (json['markers'] as List<dynamic>?)
          ?.map((e) => MapMarker.fromJson(e as Map<String, dynamic>?))
          .toList() ??
      [],
  (json['circles'] as List<dynamic>?)
          ?.map((e) => MapCircle.fromJson(e as Map<String, dynamic>?))
          .toList() ??
      [],
  (json['polygons'] as List<dynamic>?)
          ?.map((e) => MapPolygon.fromJson(e as Map<String, dynamic>?))
          .toList() ??
      [],
  (json['polylines'] as List<dynamic>?)
          ?.map((e) => MapPolyline.fromJson(e as Map<String, dynamic>?))
          .toList() ??
      [],
);

Map<String, dynamic> _$MapDataToJson(MapData instance) => <String, dynamic>{
  'markers': instance.markers?.map((e) => e.toJson()).toList(),
  'circles': instance.circles?.map((e) => e.toJson()).toList(),
  'polygons': instance.polygons?.map((e) => e.toJson()).toList(),
  'polylines': instance.polylines?.map((e) => e.toJson()).toList(),
};
