import 'package:fabric_flutter/component/alert_data.dart';
import 'package:fabric_flutter/helper/app_global.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a [MaterialApp] wired the way consumers must wire it for the
/// contextless alert path to resolve a root context.
Widget _wiredApp({Widget? child}) => MaterialApp(
  navigatorKey: AppGlobal.navigatorKey,
  scaffoldMessengerKey: AppGlobal.snackbarKey,
  home: Scaffold(body: child ?? const SizedBox.shrink()),
);

/// Captures the [BuildContext] of the element it builds into [target].
class _ContextProbe extends StatelessWidget {
  const _ContextProbe(this.target);

  /// Receives the captured context on every build.
  final List<BuildContext> target;

  @override
  Widget build(BuildContext context) {
    target.add(context);
    return const SizedBox.shrink();
  }
}

void main() {
  group('alertData', () {
    setUp(() {
      // Each test needs a pristine key: a GlobalKey cannot be attached to two
      // trees, and a key left over from a torn-down pump would still resolve.
      AppGlobal.navigatorKey = GlobalKey<NavigatorState>();
    });

    testWidgets('should resolve the root context when context is omitted', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(_wiredApp());

      // Act — no context argument at all, as a post-await caller would write it
      alertData(body: 'contextless', widget: AlertWidget.snackBar);
      await tester.pump();

      // Assert
      expect(find.text('contextless'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('should fall back to the root context when the supplied '
        'context is unmounted', (tester) async {
      // Arrange — capture a context, then rebuild without the probe so the
      // element backing it is unmounted.
      final captured = <BuildContext>[];
      await tester.pumpWidget(_wiredApp(child: _ContextProbe(captured)));
      final staleContext = captured.first;
      await tester.pumpWidget(_wiredApp());
      expect(staleContext.mounted, isFalse);

      // Act
      alertData(
        context: staleContext,
        body: 'stale',
        widget: AlertWidget.snackBar,
      );
      await tester.pump();

      // Assert — falls back instead of throwing or silently dropping the alert
      expect(find.text('stale'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('should degrade to a log when nothing is wired up', () {
      // Arrange — no MaterialApp, so the navigator key has no current context

      // Act & Assert
      expect(
        () => alertData(body: 'nowhere', widget: AlertWidget.snackBar),
        returnsNormally,
      );
      expect(AppGlobal.navigatorKey.currentContext, isNull);
    });

    test(
      'should degrade to a log when a null context is passed explicitly',
      () {
        // Arrange, Act & Assert — the parameter stays nullable, so existing
        // callers forwarding a nullable context keep working.
        expect(
          () => alertData(
            context: null,
            body: 'nowhere',
            widget: AlertWidget.snackBar,
          ),
          returnsNormally,
        );
      },
    );
  });

  group('alertContext', () {
    setUp(() {
      AppGlobal.navigatorKey = GlobalKey<NavigatorState>();
    });

    test('should return null when nothing is available', () {
      // Arrange, Act & Assert
      expect(alertContext(null), isNull);
    });

    testWidgets('should prefer a mounted context over the root', (
      tester,
    ) async {
      // Arrange
      final captured = <BuildContext>[];
      await tester.pumpWidget(_wiredApp(child: _ContextProbe(captured)));

      // Act
      final resolved = alertContext(captured.last);

      // Assert
      expect(resolved, same(captured.last));
    });

    testWidgets('should return the root context when given null', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(_wiredApp());

      // Act
      final resolved = alertContext(null);

      // Assert
      expect(resolved, isNotNull);
      expect(resolved, same(AppGlobal.navigatorKey.currentContext));
    });

    testWidgets('should fall back to the root context when the supplied '
        'context is unmounted', (tester) async {
      // Arrange — capture a context, then rebuild without the probe so the
      // element backing it is disposed. This is the case layer 1 left untested
      // at the alertContext level: an unmounted caller context previously made
      // the alert silently vanish instead of falling back to the root.
      final captured = <BuildContext>[];
      await tester.pumpWidget(_wiredApp(child: _ContextProbe(captured)));
      final staleContext = captured.first;
      await tester.pumpWidget(_wiredApp());
      expect(staleContext.mounted, isFalse);

      // Act
      final resolved = alertContext(staleContext);

      // Assert — resolves to the root rather than the dead context or null
      expect(resolved, isNotNull);
      expect(resolved, same(AppGlobal.navigatorKey.currentContext));
      expect(resolved, isNot(same(staleContext)));
    });
  });

  group('dismissAlerts', () {
    setUp(() {
      AppGlobal.navigatorKey = GlobalKey<NavigatorState>();
    });

    testWidgets('should dismiss without a context argument', (tester) async {
      // Arrange
      await tester.pumpWidget(_wiredApp());
      alertData(body: 'dismiss me', widget: AlertWidget.snackBar);
      await tester.pump();
      expect(find.text('dismiss me'), findsOneWidget);

      // Act
      dismissAlerts(widget: AlertWidget.snackBar);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('dismiss me'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('should return without throwing when nothing is wired up', () {
      // Arrange, Act & Assert
      expect(
        () => dismissAlerts(widget: AlertWidget.snackBar),
        returnsNormally,
      );
    });
  });
}
