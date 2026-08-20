import 'package:fabric_flutter/component/smart_image.dart';
import 'package:fabric_flutter/view/view_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [ViewHero] on a route carrying [arguments], mirroring how the view is
/// reached in production (via named-route navigation with a `url`/`title` map).
///
/// Routing through [Navigator] is required because [ViewHero] reads its media
/// URL from [ModalRoute.of], so a bare `home:` mount would surface no
/// arguments.
Future<void> _pumpHero(
  WidgetTester tester,
  Object? arguments,
) async {
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        builder: (_) => const ViewHero(),
        settings: RouteSettings(name: '/hero', arguments: arguments),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ViewHero', () {
    group('media rendering', () {
      testWidgets('should render a zoomable SmartImage when a url is given', (
        WidgetTester tester,
      ) async {
        // Arrange
        final arguments = <String, dynamic>{'url': 'https://example.com/a.jpg'};

        // Act
        await _pumpHero(tester, arguments);

        // Assert
        expect(find.byType(SmartImage), findsOneWidget);
        expect(find.byType(Hero), findsOneWidget);
        expect(find.byType(InteractiveViewer), findsOneWidget);
      });

      testWidgets('should forward the title as the image semantics label', (
        WidgetTester tester,
      ) async {
        // Arrange
        const label = 'Photo of a sunset';
        final arguments = <String, dynamic>{
          'url': 'https://example.com/a.jpg',
          'title': label,
        };

        // Act
        await _pumpHero(tester, arguments);

        // Assert
        final image = tester.widget<SmartImage>(find.byType(SmartImage));
        expect(image.semanticsLabel, label);
      });
    });

    group('fallback', () {
      testWidgets('should show the fallback message when no url is provided', (
        WidgetTester tester,
      ) async {
        // Arrange
        final arguments = <String, dynamic>{};

        // Act
        await _pumpHero(tester, arguments);

        // Assert
        expect(find.byType(SmartImage), findsNothing);
        expect(find.textContaining('can\'t be loaded'), findsOneWidget);
      });

      testWidgets('should show the fallback message when arguments are null', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pumpHero(tester, null);

        // Assert
        expect(find.byType(SmartImage), findsNothing);
        expect(find.textContaining('can\'t be loaded'), findsOneWidget);
      });
    });

    group('chrome', () {
      testWidgets('should always expose a close button in the app bar', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pumpHero(tester, <String, dynamic>{'url': 'https://x/y.jpg'});

        // Assert
        expect(find.byType(CloseButton), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
      });
    });
  });
}
