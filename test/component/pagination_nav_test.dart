import 'package:fabric_flutter/component/pagination_nav.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] with a loaded localization delegate inside a wide viewport so
/// [PaginationNav]'s horizontal (>=800px) layout branch is exercised and every
/// navigation control is laid out on screen.
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalizationsDelegate(locales: {})],
      supportedLocales: const [Locale('en', 'US')],
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

/// Builds a [PaginationNav] wiring each callback to a counter map so tests can
/// assert which navigation action fired.
///
/// [counters] accumulates invocation counts keyed by action name; the remaining
/// parameters mirror the widget's own configuration surface.
PaginationNav _nav({
  required Map<String, int> counters,
  int page = 2,
  int totalPages = 5,
  bool canPaginate = true,
  bool withFirstLast = true,
  ValueChanged<int>? limitChange,
}) => PaginationNav(
  page: page,
  totalPages: totalPages,
  limit: 10,
  canPaginate: canPaginate,
  next: () async => counters['next'] = (counters['next'] ?? 0) + 1,
  previous: () async =>
      counters['previous'] = (counters['previous'] ?? 0) + 1,
  first: withFirstLast
      ? () async => counters['first'] = (counters['first'] ?? 0) + 1
      : null,
  last: withFirstLast
      ? () async => counters['last'] = (counters['last'] ?? 0) + 1
      : null,
  limitChange: limitChange ?? (_) {},
);

void main() {
  group('PaginationNav', () {
    group('display', () {
      testWidgets('should show the current page and total', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(tester, _nav(counters: {}, page: 3, totalPages: 7));

        // Assert
        expect(find.textContaining('3'), findsWidgets);
        expect(find.textContaining('/ 7'), findsOneWidget);
      });

      testWidgets('should render first and last controls when provided', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(tester, _nav(counters: {}));

        // Assert
        expect(find.byIcon(Icons.first_page), findsOneWidget);
        expect(find.byIcon(Icons.last_page), findsOneWidget);
      });

      testWidgets('should omit first and last controls when not provided', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(tester, _nav(counters: {}, withFirstLast: false));

        // Assert
        expect(find.byIcon(Icons.first_page), findsNothing);
        expect(find.byIcon(Icons.last_page), findsNothing);
      });
    });

    group('navigation callbacks', () {
      testWidgets('should invoke next when the next button is tapped', (
        WidgetTester tester,
      ) async {
        // Arrange
        final counters = <String, int>{};

        // Act
        await _pump(tester, _nav(counters: counters));
        await tester.tap(find.byIcon(Icons.arrow_forward));
        await tester.pumpAndSettle();

        // Assert
        expect(counters['next'], 1);
      });

      testWidgets('should invoke previous when the back button is tapped', (
        WidgetTester tester,
      ) async {
        // Arrange
        final counters = <String, int>{};

        // Act
        await _pump(tester, _nav(counters: counters));
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // Assert
        expect(counters['previous'], 1);
      });

      testWidgets('should invoke first and last when their buttons fire', (
        WidgetTester tester,
      ) async {
        // Arrange
        final counters = <String, int>{};

        // Act
        await _pump(tester, _nav(counters: counters));
        await tester.tap(find.byIcon(Icons.first_page));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.last_page));
        await tester.pumpAndSettle();

        // Assert
        expect(counters['first'], 1);
        expect(counters['last'], 1);
      });
    });

    group('boundary disabling', () {
      testWidgets('should disable back/first on the first page', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(tester, _nav(counters: {}, page: 1));

        // Assert – the previous button is disabled at the lower boundary.
        final previous = tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.byIcon(Icons.arrow_back),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(previous.onPressed, isNull);
      });

      testWidgets('should disable next when pagination is exhausted', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(tester, _nav(counters: {}, canPaginate: false));

        // Assert
        final next = tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.byIcon(Icons.arrow_forward),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(next.onPressed, isNull);
      });

      testWidgets('should disable the last button on the final page', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(tester, _nav(counters: {}, page: 5, totalPages: 5));

        // Assert
        final last = tester.widget<TextButton>(
          find.ancestor(
            of: find.byIcon(Icons.last_page),
            matching: find.byType(TextButton),
          ),
        );
        expect(last.onPressed, isNull);
      });
    });
  });
}
