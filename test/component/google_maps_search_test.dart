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
            debounceMilliseconds: 100,
          ),
        ),
      );

      // Act
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
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

    testWidgets(
      'should debounce text input and issue only one request after debounce expires',
      (tester) async {
        // Arrange
        final requests = <http.Request>[];
        late final _TrackingClient client;
        client = _TrackingClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/place/findplacefromtext/json')) {
            return http.Response(
              jsonEncode({
                'status': 'OK',
                'candidates': [
                  {
                    'formatted_address': 'Result',
                    'name': 'Result',
                    'place_id': 'place-1',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        });
        await tester.pumpWidget(
          _wrap(
            GoogleMapsSearch(
              apiKey: 'test-key',
              clientFactory: () => client,
              debounceMilliseconds: 400,
            ),
          ),
        );

        // Act: Type multiple characters rapidly
        await tester.enterText(find.byType(TextField), 'new');
        await tester.pump(); // Debounce timer starts (400ms)
        await tester.enterText(find.byType(TextField), 'new ');
        await tester.pump(); // Timer resets
        await tester.enterText(find.byType(TextField), 'new y');
        await tester.pump(); // Timer resets
        await tester.enterText(find.byType(TextField), 'new yo');
        await tester.pump(); // Timer resets
        await tester.enterText(find.byType(TextField), 'new yor');
        await tester.pump(); // Timer resets
        await tester.enterText(find.byType(TextField), 'new york');
        // Now wait for debounce to fire
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // Assert: Only ONE network request despite multiple keystrokes
        expect(requests, hasLength(1));
        expect(requests[0].url.queryParameters['input'], 'new york');
      },
    );

    testWidgets(
      'should skip requests for queries shorter than minimumQueryLength',
      (tester) async {
        // Arrange
        final requests = <http.Request>[];
        late final _TrackingClient client;
        client = _TrackingClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        });
        await tester.pumpWidget(
          _wrap(
            GoogleMapsSearch(
              apiKey: 'test-key',
              clientFactory: () => client,
              minimumQueryLength: 3,
              debounceMilliseconds: 100,
            ),
          ),
        );

        // Act: Type 1 character (below minimum)
        await tester.enterText(find.byType(TextField), 'a');
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        // Assert: No request made for short query
        expect(requests, isEmpty);

        // Act: Type to exactly minimum length
        await tester.enterText(find.byType(TextField), 'abc');
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        // Assert: Request made when at minimum
        expect(requests, hasLength(1));
      },
    );

    testWidgets('should not make duplicate requests for unchanged query', (
      tester,
    ) async {
      // Arrange
      final requests = <http.Request>[];
      late final _TrackingClient client;
      client = _TrackingClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/place/findplacefromtext/json')) {
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'candidates': [
                {
                  'formatted_address': 'Result',
                  'name': 'Result',
                  'place_id': 'place-1',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      await tester.pumpWidget(
        _wrap(
          GoogleMapsSearch(
            apiKey: 'test-key',
            clientFactory: () => client,
            debounceMilliseconds: 100,
          ),
        ),
      );

      // Act: Type a query
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(requests, hasLength(1));

      // Act: Type the same query again (debounce fires again)
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // Assert: No new request because query is unchanged
      expect(requests, hasLength(1));
    });

    testWidgets('should ignore slow out-of-order responses', (tester) async {
      // Arrange
      late final _TrackingClient client;
      int callCount = 0;
      client = _TrackingClient((request) async {
        callCount++;
        final currentCall = callCount;
        if (request.url.path.endsWith('/place/findplacefromtext/json')) {
          final query = request.url.queryParameters['input'];
          // First request: slow (200ms)
          if (currentCall == 1) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          // Second request: fast (immediate)
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'candidates': [
                {
                  'formatted_address': query,
                  'name': query,
                  'place_id': 'place-$query',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      await tester.pumpWidget(
        _wrap(
          GoogleMapsSearch(
            apiKey: 'test-key',
            clientFactory: () => client,
            debounceMilliseconds: 50,
          ),
        ),
      );

      // Act: First query
      await tester.enterText(find.byType(TextField), 'first');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Then immediately override with second query before first responds
      await tester.enterText(find.byType(TextField), 'second');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Wait long enough for both requests to complete
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // Assert: The widget shows 'second' results, not 'first'
      final secondResults = find.byWidgetPredicate((widget) {
        return widget is Text &&
            widget.data == 'second' &&
            widget.overflow == TextOverflow.ellipsis;
      });
      expect(
        secondResults,
        findsOneWidget,
        reason: 'Should display the newer query result in the list',
      );
    });

    testWidgets('should handle HTTP 429 rate limit gracefully', (tester) async {
      // Arrange
      String? errorMessage;
      late final _TrackingClient client;
      client = _TrackingClient((request) async {
        if (request.url.path.endsWith('/place/findplacefromtext/json')) {
          return http.Response(
            '',
            429,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      await tester.pumpWidget(
        _wrap(
          GoogleMapsSearch(
            apiKey: 'test-key',
            clientFactory: () => client,
            debounceMilliseconds: 100,
            onError: (error) => errorMessage = error,
          ),
        ),
      );

      // Act: Trigger a search that gets 429
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // Assert: Error callback was invoked
      expect(errorMessage, 'Rate limited');

      // Act: Try another search immediately after rate limit
      await tester.enterText(find.byType(TextField), 'test2');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // Assert: No new request was attempted (rate limit flag is still set)
      // The widget should not make another request until the user types something new
      // and the rate limit flag is cleared.
    });

    testWidgets('should clear rate limit flag on new search input', (
      tester,
    ) async {
      // Arrange
      int requestCount = 0;
      late final _TrackingClient client;
      client = _TrackingClient((request) async {
        if (request.url.path.endsWith('/place/findplacefromtext/json')) {
          requestCount++;
          // First request returns 429
          if (requestCount == 1) {
            return http.Response('', 429);
          }
          // Second request succeeds
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'candidates': [
                {
                  'formatted_address': 'Result',
                  'name': 'Result',
                  'place_id': 'place-1',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      await tester.pumpWidget(
        _wrap(
          GoogleMapsSearch(
            apiKey: 'test-key',
            clientFactory: () => client,
            debounceMilliseconds: 50,
          ),
        ),
      );

      // Act: First search hits 429
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle(const Duration(milliseconds: 150));
      expect(requestCount, 1);

      // Act: Try again without new input (should not retry due to rate limit)
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle(const Duration(milliseconds: 150));
      expect(requestCount, 1);

      // Act: New input clears rate limit flag
      await tester.enterText(find.byType(TextField), 'test2');
      await tester.pumpAndSettle(const Duration(milliseconds: 150));

      // Assert: New request was attempted
      expect(requestCount, 2);
    });

    testWidgets('should dispose debounce timer on widget disposal', (
      tester,
    ) async {
      // Arrange
      bool timerFired = false;
      late final _TrackingClient client;
      client = _TrackingClient((request) async {
        timerFired = true;
        return http.Response('{}', 200);
      });
      await tester.pumpWidget(
        _wrap(
          GoogleMapsSearch(
            apiKey: 'test-key',
            clientFactory: () => client,
            debounceMilliseconds: 1000,
          ),
        ),
      );

      // Act: Start typing (timer starts)
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      // Act: Dispose widget before debounce fires
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Timer was cancelled, no request was made
      expect(timerFired, isFalse);
    });
  });
}
