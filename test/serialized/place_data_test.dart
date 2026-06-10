import 'package:fabric_flutter/serialized/place_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dayTimeToDateTime', () {
    test('should build a UTC DateTime from a weekday and HHmm time', () {
      // Arrange
      const day = 1;
      const time = '0930';

      // Act
      final result = dayTimeToDateTime(day, time);

      // Assert
      expect(result.isUtc, isTrue);
      expect(result.hour, 9);
      expect(result.minute, 30);
    });

    test('should parse the boundary midnight time', () {
      // Arrange & Act
      final result = dayTimeToDateTime(2, '0000');

      // Assert
      expect(result.hour, 0);
      expect(result.minute, 0);
    });

    test(
      'should throw ArgumentError when the time has fewer than 4 digits',
      () {
        // Arrange, Act & Assert
        expect(
          () => dayTimeToDateTime(1, '930'),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group('Location', () {
    test('should deserialize lat and lng from JSON', () {
      // Arrange
      final json = <String, dynamic>{'lat': 40.5, 'lng': -73.2};

      // Act
      final location = Location.fromJson(json);

      // Assert
      expect(location.lat, 40.5);
      expect(location.lng, -73.2);
    });

    test('should expose a lat,lng string representation', () {
      // Arrange
      final location = Location(lat: 1.0, lng: 2.0);

      // Act
      final asString = location.toString();

      // Assert
      expect(asString, '1.0,2.0');
    });

    test('should serialize back to JSON', () {
      // Arrange
      final location = Location(lat: 3.0, lng: 4.0);

      // Act
      final json = location.toJson();

      // Assert
      expect(json, {'lat': 3.0, 'lng': 4.0});
    });
  });

  group('Bounds', () {
    test('should expose a pipe-delimited corner representation', () {
      // Arrange
      final bounds = Bounds(
        northeast: Location(lat: 1.0, lng: 2.0),
        southwest: Location(lat: 3.0, lng: 4.0),
      );

      // Act
      final asString = bounds.toString();

      // Assert
      expect(asString, '1.0,2.0|3.0,4.0');
    });

    test('should round-trip through JSON', () {
      // Arrange
      final bounds = Bounds(
        northeast: Location(lat: 5.0, lng: 6.0),
        southwest: Location(lat: 7.0, lng: 8.0),
      );

      // Act
      final restored = Bounds.fromJson(bounds.toJson());

      // Assert
      expect(restored.northeast.lat, 5.0);
      expect(restored.southwest.lng, 8.0);
    });
  });

  group('PlusCode', () {
    test('should map snake_case keys to camelCase fields', () {
      // Arrange
      final json = <String, dynamic>{
        'global_code': '849VCWC8+R9',
        'compound_code': 'CWC8+R9 Mountain View',
      };

      // Act
      final plusCode = PlusCode.fromJson(json);

      // Assert
      expect(plusCode.globalCode, '849VCWC8+R9');
      expect(plusCode.compoundCode, 'CWC8+R9 Mountain View');
    });

    test('should allow a null compound code', () {
      // Arrange
      final json = <String, dynamic>{'global_code': 'GLOBAL'};

      // Act
      final plusCode = PlusCode.fromJson(json);

      // Assert
      expect(plusCode.compoundCode, isNull);
    });
  });

  group('PlacesResponse', () {
    test('should fall back to default collections for an empty payload', () {
      // Arrange & Act
      final response = PlacesResponse.fromJson(<String, dynamic>{
        'status': 'OK',
      });

      // Assert
      expect(response.status, 'OK');
      expect(response.candidates, isEmpty);
      expect(response.htmlAttributions, isEmpty);
      expect(response.nextPageToken, isNull);
      expect(response.errorMessage, isNull);
    });

    test('should read the error message from a failed response', () {
      // Arrange
      final json = <String, dynamic>{
        'status': 'REQUEST_DENIED',
        'error_message': 'The provided API key is invalid.',
      };

      // Act
      final response = PlacesResponse.fromJson(json);

      // Assert
      expect(response.status, 'REQUEST_DENIED');
      expect(response.errorMessage, 'The provided API key is invalid.');
    });
  });

  group('OpeningHoursPeriodDate', () {
    test('toDateTime should convert day and time into a UTC DateTime', () {
      // Arrange
      final periodDate = OpeningHoursPeriodDate(day: 1, time: '0800');

      // Act
      final dateTime = periodDate.toDateTime();

      // Assert
      expect(dateTime.isUtc, isTrue);
      expect(dateTime.hour, 8);
      expect(dateTime.minute, 0);
    });
  });
}
