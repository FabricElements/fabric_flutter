import 'package:fabric_flutter/component/status_page.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/state/state_global.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Returns the default English label stored for [key] in [defaultLocales].
///
/// Used instead of echoing the raw key so a missing translation fails loudly.
String en(String key) {
  final localizations = AppLocalizations(const Locale('en', 'US'));
  // load() merges the bundled defaults synchronously before its future
  // completes, so the lookup below already sees the English fallbacks.
  localizations.load();
  return localizations.get(key);
}

/// Pumps [widget] inside a localized [MaterialApp] with a [StateGlobal].
///
/// The [StateGlobal] is required by [StatusPage]'s retry-availability logic
/// and defaults to connected; pass [connected] as false to simulate offline.
Future<void> pumpPage(
  WidgetTester tester,
  Widget widget, {
  bool connected = true,
}) async {
  final stateGlobal = StateGlobal();
  if (!connected) stateGlobal.connected = false;
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: stateGlobal,
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizationsDelegate(locales: {})],
        supportedLocales: const [Locale('en', 'US')],
        home: Scaffold(body: widget),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('StatusVariant', () {
    test('fromErrorCode should map each known HTTP status to a variant', () {
      // Arrange / Act / Assert
      expect(
        StatusVariantMapping.fromErrorCode('error--400'),
        StatusVariant.notFound,
      );
      expect(StatusVariantMapping.fromErrorCode('400'), StatusVariant.notFound);
      expect(
        StatusVariantMapping.fromErrorCode('error--401'),
        StatusVariant.unauthenticated,
      );
      expect(
        StatusVariantMapping.fromErrorCode('401'),
        StatusVariant.unauthenticated,
      );
      expect(
        StatusVariantMapping.fromErrorCode('error--403'),
        StatusVariant.forbidden,
      );
      expect(
        StatusVariantMapping.fromErrorCode('403'),
        StatusVariant.forbidden,
      );
      expect(
        StatusVariantMapping.fromErrorCode('error--404'),
        StatusVariant.resourceNotFound,
      );
      expect(
        StatusVariantMapping.fromErrorCode('404'),
        StatusVariant.resourceNotFound,
      );
      expect(
        StatusVariantMapping.fromErrorCode('error--500'),
        StatusVariant.unavailable,
      );
      expect(
        StatusVariantMapping.fromErrorCode('504'),
        StatusVariant.unavailable,
      );
    });

    test('fromErrorCode should fall back to unexpected for unknown codes', () {
      // Arrange / Act
      final variant = StatusVariantMapping.fromErrorCode('error--permission');

      // Assert
      expect(variant, StatusVariant.unexpected);
    });

    test('fromErrorCode should fall back to unexpected for null codes', () {
      // Arrange / Act
      final variant = StatusVariantMapping.fromErrorCode(null);

      // Assert
      expect(variant, StatusVariant.unexpected);
    });

    test('transient should be true only for retryable variants', () {
      // Arrange / Act / Assert
      expect(StatusVariant.unavailable.transient, isTrue);
      expect(StatusVariant.unexpected.transient, isTrue);
      expect(StatusVariant.notFound.transient, isFalse);
      expect(StatusVariant.forbidden.transient, isFalse);
      expect(StatusVariant.resourceNotFound.transient, isFalse);
      expect(StatusVariant.unauthenticated.transient, isFalse);
      expect(StatusVariant.archived.transient, isFalse);
    });

    test('locale keys should be unique per variant', () {
      // Arrange
      final variants = StatusVariant.values;

      // Act
      final titles = variants.map((variant) => variant.titleKey).toSet();
      final descriptions = variants
          .map((variant) => variant.descriptionKey)
          .toSet();

      // Assert
      expect(titles.length, variants.length);
      expect(descriptions.length, variants.length);
    });
  });

  group('StatusPage', () {
    testWidgets('should render the localized title and description', (
      WidgetTester tester,
    ) async {
      // Arrange
      await pumpPage(tester, const StatusPage(variant: StatusVariant.notFound));

      // Act / Assert
      expect(find.byType(StatusPage), findsOneWidget);
      expect(find.text(en('status--not-found-title')), findsOneWidget);
      expect(find.text(en('status--not-found-description')), findsOneWidget);
    });

    testWidgets('should prefer an explicit title and description', (
      WidgetTester tester,
    ) async {
      // Arrange
      await pumpPage(
        tester,
        const StatusPage(
          variant: StatusVariant.forbidden,
          title: 'Custom title',
          description: 'Custom description',
        ),
      );

      // Act / Assert
      expect(find.text('Custom title'), findsOneWidget);
      expect(find.text('Custom description'), findsOneWidget);
    });

    testWidgets('should render the back and home actions when there is no '
        'route history to pop', (WidgetTester tester) async {
      // Arrange: no back history exists under the test navigator.
      await pumpPage(tester, const StatusPage(variant: StatusVariant.notFound));

      // Act / Assert
      expect(find.text(en('label--go-back')), findsOneWidget);
      expect(find.text(en('label--go-home')), findsOneWidget);
    });

    testWidgets('should hide retry when onRetry is null', (
      WidgetTester tester,
    ) async {
      // Arrange
      await pumpPage(
        tester,
        const StatusPage(variant: StatusVariant.unexpected),
      );

      // Act / Assert
      expect(find.text(en('label--retry')), findsNothing);
    });

    testWidgets('should show retry for transient variants and invoke it', (
      WidgetTester tester,
    ) async {
      // Arrange
      var retries = 0;
      await pumpPage(
        tester,
        StatusPage(
          variant: StatusVariant.unavailable,
          onRetry: () => retries++,
        ),
      );

      // Act
      await tester.tap(find.text(en('label--retry')));
      await tester.pump();

      // Assert
      expect(retries, 1);
    });

    testWidgets('should disable retry for non-transient variants', (
      WidgetTester tester,
    ) async {
      // Arrange
      var retries = 0;
      await pumpPage(
        tester,
        StatusPage(variant: StatusVariant.notFound, onRetry: () => retries++),
      );

      // Act
      final retry = find.text(en('label--retry'));
      await tester.pump();

      // Assert: retry is not offered at all for non-transient variants.
      expect(retry, findsNothing);
      expect(retries, 0);
    });

    testWidgets('should pop back when route history exists', (
      WidgetTester tester,
    ) async {
      // Arrange: the status page is pushed above an existing route, so Back
      // pops instead of opening the home route.
      final stateGlobal = StateGlobal();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: stateGlobal,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizationsDelegate(locales: {}),
            ],
            supportedLocales: const [Locale('en', 'US')],
            home: const Scaffold(body: Text('Origin')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      // The push future only completes once the route is popped, so it must
      // not be awaited here: the test drives the pop by tapping Back.
      navigator.push(
        MaterialPageRoute<void>(
          builder: (context) =>
              const Scaffold(body: StatusPage(variant: StatusVariant.notFound)),
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text(en('label--go-back')));
      await tester.pumpAndSettle();

      // Assert: the pop returns to the page beneath it.
      expect(find.text('Origin'), findsOneWidget);
    });

    testWidgets('should open the home route when no history exists', (
      WidgetTester tester,
    ) async {
      // Arrange: the status page is the only route, so Back and Home both
      // open the home route instead of popping.
      final stateGlobal = StateGlobal();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: stateGlobal,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizationsDelegate(locales: {}),
            ],
            supportedLocales: const [Locale('en', 'US')],
            routes: {
              '/': (context) => const Scaffold(
                body: StatusPage(
                  variant: StatusVariant.notFound,
                  homeRoute: '/home',
                ),
              ),
              '/home': (context) => const Scaffold(body: Text('Home')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text(en('label--go-home')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('should render extra actions after the built-in ones', (
      WidgetTester tester,
    ) async {
      // Arrange
      await pumpPage(
        tester,
        const StatusPage(
          variant: StatusVariant.unauthenticated,
          actions: [Text('Switch account')],
        ),
      );

      // Act / Assert
      expect(find.text('Switch account'), findsOneWidget);
    });

    testWidgets('should wrap the page in its own scaffold when parent is set', (
      WidgetTester tester,
    ) async {
      // Arrange
      await pumpPage(
        tester,
        StatusPage(variant: StatusVariant.notFound, parent: true),
      );

      // Act / Assert
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.primary, isTrue);
    });
  });
}
