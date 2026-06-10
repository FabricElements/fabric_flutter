import 'package:fabric_flutter/serialized/map_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapLatLng', () {
    test('should default both coordinates to 0.0 for an empty payload', () {
      // Arrange & Act
      final latLng = MapLatLng.fromJson(null);

      // Assert
      expect(latLng.latitude, 0.0);
      expect(latLng.longitude, 0.0);
    });

    test('should parse integer coordinates into doubles', () {
      // Arrange
      final json = <String, dynamic>{'latitude': 10, 'longitude': -20};

      // Act
      final latLng = MapLatLng.fromJson(json);

      // Assert
      expect(latLng.latitude, 10.0);
      expect(latLng.longitude, -20.0);
    });

    test('should serialize coordinates back to JSON', () {
      // Arrange
      final latLng = MapLatLng(1.5, 2.5);

      // Act
      final json = latLng.toJson();

      // Assert
      expect(json, {'latitude': 1.5, 'longitude': 2.5});
    });
  });

  group('MapMarker', () {
    test('should apply default name and description when missing', () {
      // Arrange
      final json = <String, dynamic>{
        'position': {'latitude': 5.0, 'longitude': 6.0},
      };

      // Act
      final marker = MapMarker.fromJson(json);

      // Assert
      expect(marker.name, '');
      expect(marker.description, '');
      expect(marker.position.latitude, 5.0);
    });

    test('should round-trip a fully populated marker', () {
      // Arrange
      final marker = MapMarker(MapLatLng(1.0, 2.0), 'Home', 'My house');

      // Act
      final restored = MapMarker.fromJson(marker.toJson());

      // Assert
      expect(restored.name, 'Home');
      expect(restored.description, 'My house');
      expect(restored.position.longitude, 2.0);
    });
  });

  group('MapCircle', () {
    test('should default radius to 0 when omitted', () {
      // Arrange
      final json = <String, dynamic>{
        'center': {'latitude': 0.0, 'longitude': 0.0},
      };

      // Act
      final circle = MapCircle.fromJson(json);

      // Assert
      expect(circle.radius, 0);
    });
  });

  group('MapPatternItem', () {
    test('should default to a dot pattern when value is missing', () {
      // Arrange & Act
      final item = MapPatternItem.fromJson(<String, dynamic>{});

      // Assert
      expect(item.pattern, MapPattern.dot);
      expect(item.length, 0);
    });

    test('should decode a dash pattern from its JSON value', () {
      // Arrange
      final json = <String, dynamic>{'pattern': 'dash', 'length': 4};

      // Act
      final item = MapPatternItem.fromJson(json);

      // Assert
      expect(item.pattern, MapPattern.dash);
      expect(item.length, 4.0);
    });

    test('should serialize the pattern enum to its JSON string value', () {
      // Arrange
      final item = MapPatternItem(MapPattern.gap, 2.0);

      // Act
      final json = item.toJson();

      // Assert
      expect(json['pattern'], 'gap');
      expect(json['length'], 2.0);
    });
  });

  group('MapPolygon', () {
    test('should default points and holes to empty lists', () {
      // Arrange & Act
      final polygon = MapPolygon.fromJson(null);

      // Assert
      expect(polygon.points, isEmpty);
      expect(polygon.holes, isEmpty);
    });

    test('should parse nested holes as lists of coordinates', () {
      // Arrange
      final json = <String, dynamic>{
        'points': [
          {'latitude': 1.0, 'longitude': 1.0},
        ],
        'holes': [
          [
            {'latitude': 2.0, 'longitude': 2.0},
          ],
        ],
      };

      // Act
      final polygon = MapPolygon.fromJson(json);

      // Assert
      expect(polygon.points, hasLength(1));
      expect(polygon.holes, hasLength(1));
      expect(polygon.holes.first.first.latitude, 2.0);
    });
  });

  group('MapData', () {
    test('should default every overlay collection to an empty list', () {
      // Arrange & Act
      final data = MapData.fromJson(null);

      // Assert
      expect(data.markers, isEmpty);
      expect(data.circles, isEmpty);
      expect(data.polygons, isEmpty);
      expect(data.polylines, isEmpty);
    });

    test('should round-trip overlays through JSON', () {
      // Arrange
      final data = MapData(
        [MapMarker(MapLatLng(1.0, 1.0), 'A', '')],
        [MapCircle(MapLatLng(2.0, 2.0), 5.0)],
        const [],
        const [],
      );

      // Act
      final restored = MapData.fromJson(data.toJson());

      // Assert
      expect(restored.markers, hasLength(1));
      expect(restored.markers!.first.name, 'A');
      expect(restored.circles!.first.radius, 5.0);
    });
  });
}
