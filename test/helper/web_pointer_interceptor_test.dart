import 'package:fabric_flutter/helper/web_pointer_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

void main() {
  group('WebPointerInterceptor', () {
    testWidgets('should not add a native interceptor outside the web', (
      tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(home: WebPointerInterceptor(child: Text('child'))),
      );

      // Assert
      expect(find.byType(PointerInterceptor), findsNothing);
      expect(find.text('child'), findsOneWidget);
    });
  });
}
