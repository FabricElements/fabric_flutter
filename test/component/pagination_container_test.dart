import 'dart:async';

import 'package:fabric_flutter/component/pagination_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaginationContainer', () {
    testWidgets(
      'should not throw and should still run pagination detection when '
      'onScrollOffsetChanged throws',
      (WidgetTester tester) async {
        // Arrange
        final items = List<int>.generate(40, (index) => index);
        final streamController = StreamController<dynamic>.broadcast();
        var paginateCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                child: PaginationContainer(
                  initialData: items,
                  stream: streamController.stream,
                  onScrollOffsetChanged: (_) => throw StateError('boom offset'),
                  itemBuilder: (context, index, data) =>
                      SizedBox(height: 100, child: Text('item $data')),
                  paginate: () async {
                    paginateCalled = true;
                    return null;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Act: scroll the list to its trailing edge to trigger the scroll
        // listener (and the throwing onScrollOffsetChanged callback) before
        // the pagination-detection logic that follows it in the same
        // listener.
        final controller = tester
            .widget<ListView>(find.byType(ListView))
            .controller!;
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        // Assert: the throwing callback never escapes the scroll listener,
        // and pagination detection still runs afterward.
        expect(tester.takeException(), isNull);
        expect(paginateCalled, isTrue);

        await streamController.close();
      },
    );

    testWidgets(
      'should route a scroll-listener callback failure to onError when '
      'provided',
      (WidgetTester tester) async {
        // Arrange
        final items = List<int>.generate(40, (index) => index);
        final streamController = StreamController<dynamic>.broadcast();
        final errors = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                child: PaginationContainer(
                  initialData: items,
                  stream: streamController.stream,
                  onScrollOffsetChanged: (_) => throw StateError('boom offset'),
                  onError: errors.add,
                  itemBuilder: (context, index, data) =>
                      SizedBox(height: 100, child: Text('item $data')),
                  paginate: () async => null,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Act
        final controller = tester
            .widget<ListView>(find.byType(ListView))
            .controller!;
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        // Assert
        expect(tester.takeException(), isNull);
        expect(
          errors,
          contains(
            'PaginationContainer.onScrollOffsetChanged threw: '
            'Bad state: boom offset',
          ),
        );

        await streamController.close();
      },
    );

    testWidgets('should route a paginate() failure to onError when provided', (
      WidgetTester tester,
    ) async {
      // Arrange
      final items = List<int>.generate(40, (index) => index);
      final streamController = StreamController<dynamic>.broadcast();
      final errors = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: PaginationContainer(
                initialData: items,
                stream: streamController.stream,
                onError: errors.add,
                itemBuilder: (context, index, data) =>
                    SizedBox(height: 100, child: Text('item $data')),
                paginate: () async => throw StateError('boom paginate'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act
      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
      expect(errors, ['Bad state: boom paginate']);

      await streamController.close();
    });
  });
}
