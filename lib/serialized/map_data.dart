import 'package:json_annotation/json_annotation.dart';

part 'map_data.g.dart';

/// A pair of latitude and longitude coordinates, stored as degrees.
/// Creates a geographical location specified in degrees [latitude] and
/// [longitude].
///
/// The latitude is clamped to the inclusive interval from -90.0 to +90.0.
///
/// The longitude is normalized to the half-open interval from -180.0
/// (inclusive) to +180.0 (exclusive).
@JsonSerializable(explicitToJson: true)
class MapLatLng {
  @JsonKey(includeIfNull: true, defaultValue: 0.0)
  final double? latitude;
  @JsonKey(includeIfNull: true, defaultValue: 0.0)
  final double? longitude;

  MapLatLng(
    this.latitude,
    this.longitude,
  );

  factory MapLatLng.fromJson(Map<String, dynamic>? json) =>
      _$MapLatLngFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$MapLatLngToJson(this);
}

/// Marks a geographical location on the map.
///
/// A marker icon is drawn oriented against the device's screen rather than
/// the map's surface; that is, it will not necessarily change orientation
/// due to map rotations, tilting, or zooming.
@JsonSerializable(explicitToJson: true)
class MapMarker {
  @JsonKey(includeIfNull: true, defaultValue: null)
  final MapLatLng position;
  @JsonKey(includeIfNull: true, defaultValue: '')
  final String name;
  @JsonKey(includeIfNull: true, defaultValue: '')
  final String description;

  MapMarker(
    this.position,
    this.name,
    this.description,
  );

  factory MapMarker.fromJson(Map<String, dynamic>? json) =>
      _$MapMarkerFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$MapMarkerToJson(this);
}

/// Draws a circle on the map.
/// Creates an immutable representation of a [Circle] to draw on [GoogleMap].
@JsonSerializable(explicitToJson: true)
class MapCircle {
  @JsonKey(includeIfNull: true, defaultValue: null)
  final MapLatLng center;
  @JsonKey(includeIfNull: true, defaultValue: 0)
  final double radius;

  MapCircle(
    this.center,
    this.radius,
  );

  factory MapCircle.fromJson(Map<String, dynamic>? json) =>
      _$MapCircleFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$MapCircleToJson(this);
}

/// Draws a polygon through geographical locations on the map.
/// Creates an immutable representation of a polygon through geographical locations on the map.
@JsonSerializable(explicitToJson: true)
class MapPolygon {
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapLatLng> points;
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<List<MapLatLng>> holes;

  MapPolygon(
    this.points,
    this.holes,
  );

  factory MapPolygon.fromJson(Map<String, dynamic>? json) =>
      _$MapPolygonFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$MapPolygonToJson(this);
}

/// Draws a line through geographical locations on the map.
/// Creates an immutable object representing a line drawn through geographical locations on the map.
@JsonSerializable(explicitToJson: true)
class MapPolyline {
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapLatLng> points;
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapPatternItem> patterns;

  MapPolyline(
    this.points,
    this.patterns,
  );

  factory MapPolyline.fromJson(Map<String, dynamic>? json) =>
      _$MapPolylineFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$MapPolylineToJson(this);
}

enum MapPattern {
  /// A dot used in the stroke pattern for a [Polyline].
  @JsonValue('dot')
  dot,

  /// A dash used in the stroke pattern for a [Polyline].
  @JsonValue('dash')
  dash,

  /// A gap used in the stroke pattern for a [Polyline].
  @JsonValue('gap')
  gap,
}

/// Item used in the stroke pattern for a Polyline.
@JsonSerializable(explicitToJson: true)
class MapPatternItem {
  @JsonKey(includeIfNull: true, defaultValue: MapPattern.dot)
  final MapPattern pattern;

  /// [length] has to be non-negative.
  @JsonKey(includeIfNull: true, defaultValue: 0)
  final double length;

  MapPatternItem(
    this.pattern,
    this.length,
  );

  factory MapPatternItem.fromJson(Map<String, dynamic>? json) =>
      _$MapPatternItemFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$MapPatternItemToJson(this);
}

@JsonSerializable(explicitToJson: true)
class MapData {
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapMarker>? markers;
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapCircle>? circles;
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapPolygon>? polygons;
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapPolyline>? polylines;

  MapData(
    this.markers,
    this.circles,
    this.polygons,
    this.polylines,
  );

  factory MapData.fromJson(Map<String, dynamic>? json) =>
      _$MapDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$MapDataToJson(this);
}
