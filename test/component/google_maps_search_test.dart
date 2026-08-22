import 'dart:convert';

import 'package:fabric_flutter/component/google_maps_search.dart';
import 'package:fabric_flutter/serialized/place_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Records requests and whether the injected transport was closed.
class _TrackingClient extends MockClient {
  /// Creates a tracking client backed by [handler].
  _TrackingClient(super.handler);

  /// Indicates whether [close] has released the client.
  bool isClosed = false;

  /// Releases the client and records that disposal occurred.
  @override
  void close() {
    isClosed = true;
    super.close();
  }
}

void main() {
  group('GoogleMapsSearch', () {
    testWidgets('should render without throwing', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(_wrap(const GoogleMapsSearch(apiKey: 'test')));
      await tester.pump();

      // Assert
      expect(tester.takeException(), isNull);
    });

    testWidgets('should use one injected client for search and details', (
      tester,
    ) async {
      // Arrange
      final requests = <http.Request>[];
      Place? selectedPlace;
      late final _TrackingClient client;
      client = _TrackingClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/place/findplacefromtext/json')) {
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'candidates': [
                {
                  'formatted_address': '123 Main Street',
                  'name': 'Test Place',
                  'place_id': 'place-1',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'result': {
              'formatted_address': '123 Main Street',
              'name': 'Test Place',
              'place_id': 'place-1',
              'geometry': {
                'location': {'lat': 12.5, 'lng': -45.25},
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      await tester.pumpWidget(
        _wrap(
          GoogleMapsSearch(
            apiKey: 'test-key',
            clientFactory: () => client,
            onChange: (place) => selectedPlace = place,
          ),
        ),
      );

      // Act
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle();
      await tester.tap(find.text('123 Main Street'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump();

      // Assert
      expect(requests, hasLength(2));
      expect(requests[0].url.path, endsWith('/place/findplacefromtext/json'));
      expect(requests[0].url.queryParameters['input'], 'test');
      expect(requests[1].url.path, endsWith('/place/details/json'));
      expect(requests[1].url.queryParameters['place_id'], 'place-1');
      expect(selectedPlace?.geometry?.location.lat, 12.5);
      expect(selectedPlace?.geometry?.location.lng, -45.25);
      expect(client.isClosed, isTrue);
    });
  });
}
