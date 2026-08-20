import 'package:fabric_flutter/component/google_maps_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('GoogleMapsSearch', () {
    testWidgets('should render without throwing', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(_wrap(const GoogleMapsSearch(apiKey: 'test')));
      await tester.pump();

      // Assert
      expect(tester.takeException(), isNull);
    });

    testWidgets('should dispose cleanly when removed from the tree', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(_wrap(const GoogleMapsSearch(apiKey: 'test')));
      await tester.pump();

      // Act — replacing the widget triggers State.dispose
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump();

      // Assert
      expect(tester.takeException(), isNull);
    });
  });
}
