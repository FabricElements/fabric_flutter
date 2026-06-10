import 'package:json_annotation/json_annotation.dart';

part 'map_data.g.dart';

/// A pair of latitude and longitude coordinates, stored as degrees.
///
/// Instances of this class are used throughout the serialized map models so the
/// same simple coordinate representation can describe markers, circles, lines,
/// and polygons.
@JsonSerializable(explicitToJson: true)
class MapLatLng {
  /// Stores the latitude in degrees.
  @JsonKey(includeIfNull: true, defaultValue: 0.0)
  final double? latitude;

  /// Stores the longitude in degrees.
  @JsonKey(includeIfNull: true, defaultValue: 0.0)
  final double? longitude;

  /// Creates a geographical location in degrees.
  MapLatLng(this.latitude, this.longitude);

  /// Builds [MapLatLng] from serialized JSON.
  ///
  /// A `null` payload becomes an empty map so missing coordinate payloads can be
  /// deserialized into their default numeric values.
  factory MapLatLng.fromJson(Map<String, dynamic>? json) =>
      _$MapLatLngFromJson(json ?? {});

  /// Converts this coordinate into JSON.
  Map<String, dynamic> toJson() => _$MapLatLngToJson(this);
}

/// Marks a geographical location on the map.
///
/// Marker metadata is intentionally lightweight because these serialized models
/// are mainly used to transport map annotations between backend data and the UI.
@JsonSerializable(explicitToJson: true)
class MapMarker {
  /// Identifies where the marker should be rendered.
  @JsonKey(includeIfNull: true, defaultValue: null)
  final MapLatLng position;

  /// Provides the marker title shown by the UI.
  @JsonKey(includeIfNull: true, defaultValue: '')
  final String name;

  /// Provides additional marker details for tooltips or info windows.
  @JsonKey(includeIfNull: true, defaultValue: '')
  final String description;

  /// Creates a serialized marker definition.
  MapMarker(this.position, this.name, this.description);

  /// Builds [MapMarker] from serialized JSON.
  factory MapMarker.fromJson(Map<String, dynamic>? json) =>
      _$MapMarkerFromJson(json ?? {});

  /// Converts this marker into JSON.
  Map<String, dynamic> toJson() => _$MapMarkerToJson(this);
}

/// Describes a circle overlay on the map.
///
/// Circles are useful for radius-based searches and proximity indicators where a
/// single center point and distance communicate the desired region.
@JsonSerializable(explicitToJson: true)
class MapCircle {
  /// Stores the center point of the circle.
  @JsonKey(includeIfNull: true, defaultValue: null)
  final MapLatLng center;

  /// Stores the radius in map units expected by the consumer.
  @JsonKey(includeIfNull: true, defaultValue: 0)
  final double radius;

  /// Creates a serialized circle definition.
  MapCircle(this.center, this.radius);

  /// Builds [MapCircle] from serialized JSON.
  factory MapCircle.fromJson(Map<String, dynamic>? json) =>
      _$MapCircleFromJson(json ?? {});

  /// Converts this circle into JSON.
  Map<String, dynamic> toJson() => _$MapCircleToJson(this);
}

/// Describes a polygon overlay on the map.
///
/// Polygons support both an outer boundary and optional holes so complex areas
/// can be represented without leaking map rendering details into higher layers.
@JsonSerializable(explicitToJson: true)
class MapPolygon {
  /// Defines the outer boundary points of the polygon.
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapLatLng> points;

  /// Defines cut-out regions inside the polygon.
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<List<MapLatLng>> holes;

  /// Creates a serialized polygon definition.
  MapPolygon(this.points, this.holes);

  /// Builds [MapPolygon] from serialized JSON.
  factory MapPolygon.fromJson(Map<String, dynamic>? json) =>
      _$MapPolygonFromJson(json ?? {});

  /// Converts this polygon into JSON.
  Map<String, dynamic> toJson() => _$MapPolygonToJson(this);
}

/// Describes a polyline overlay on the map.
///
/// Polylines are typically used for routes, boundaries, or historical traces
/// where order matters but a closed area is unnecessary.
@JsonSerializable(explicitToJson: true)
class MapPolyline {
  /// Defines the ordered points that make up the line.
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapLatLng> points;

  /// Defines the stroke pattern applied to the line.
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapPatternItem> patterns;

  /// Creates a serialized polyline definition.
  MapPolyline(this.points, this.patterns);

  /// Builds [MapPolyline] from serialized JSON.
  factory MapPolyline.fromJson(Map<String, dynamic>? json) =>
      _$MapPolylineFromJson(json ?? {});

  /// Converts this polyline into JSON.
  Map<String, dynamic> toJson() => _$MapPolylineToJson(this);
}

/// Enumerates the supported stroke pattern segments for a [MapPolyline].
enum MapPattern {
  /// Draws a single dot segment.
  @JsonValue('dot')
  dot,

  /// Draws a dash segment.
  @JsonValue('dash')
  dash,

  /// Inserts a gap between visible segments.
  @JsonValue('gap')
  gap,
}

/// Stores one item in a polyline stroke pattern.
///
/// Pattern items make dashed and dotted lines serializable without requiring the
/// rendering layer to infer segment semantics from raw numeric values alone.
@JsonSerializable(explicitToJson: true)
class MapPatternItem {
  /// Selects the pattern segment type.
  @JsonKey(includeIfNull: true, defaultValue: MapPattern.dot)
  final MapPattern pattern;

  /// Stores the segment length.
  ///
  /// Lengths should be non-negative because negative distances have no meaning
  /// in the stroke pattern APIs used by map renderers.
  @JsonKey(includeIfNull: true, defaultValue: 0)
  final double length;

  /// Creates a serialized pattern item.
  MapPatternItem(this.pattern, this.length);

  /// Builds [MapPatternItem] from serialized JSON.
  factory MapPatternItem.fromJson(Map<String, dynamic>? json) =>
      _$MapPatternItemFromJson(json ?? {});

  /// Converts this pattern item into JSON.
  Map<String, dynamic> toJson() => _$MapPatternItemToJson(this);
}

/// Groups all serialized overlays needed to render a map.
///
/// Keeping markers, circles, polygons, and polylines together allows higher
/// layers to exchange a full map state as a single value object.
@JsonSerializable(explicitToJson: true)
class MapData {
  /// Stores point markers to render on the map.
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapMarker>? markers;

  /// Stores circular overlays to render on the map.
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapCircle>? circles;

  /// Stores polygon overlays to render on the map.
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapPolygon>? polygons;

  /// Stores polyline overlays to render on the map.
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<MapPolyline>? polylines;

  /// Creates a serialized map payload.
  MapData(this.markers, this.circles, this.polygons, this.polylines);

  /// Builds [MapData] from serialized JSON.
  factory MapData.fromJson(Map<String, dynamic>? json) =>
      _$MapDataFromJson(json ?? {});

  /// Converts this map payload into JSON.
  Map<String, dynamic> toJson() => _$MapDataToJson(this);
}
