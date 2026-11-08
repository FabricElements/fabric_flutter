import 'package:fabric_flutter/component/breadcrumbs.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the ordered named routes the app has visited.
///
/// Pushing a route appends it, popping removes it, and replacing a route swaps
/// it in place. That difference is what these tests assert: a redirected
/// ancestor link keeps the history intact, so the browser and system back button
/// still land on the screen the user came from.
class _RouteRecorder extends NavigatorObserver {
  /// Every route the navigator has mounted, oldest first.
  final List<String> history = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = route.settings.name;
    if (name != null) history.add(name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // A route always leaves from the top of the stack, so drop the last match.
    final name = route.settings.name;
    if (name == null) return;
    final index = history.lastIndexOf(name);
    if (index >= 0) history.removeAt(index);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final oldName = oldRoute?.settings.name;
    if (oldName == null) return;
    final index = history.lastIndexOf(oldName);
    if (index >= 0) history[index] = newRoute?.settings.name ?? '';
  }
}

/// Builds the crumb trail for a detail screen sitting below [ancestor].
List<ButtonOptions> _crumbs(ButtonOptions ancestor) => [
  ancestor,
  ButtonOptions(label: 'Current'),
];

/// Pumps a three level app: home, a mid level list, and a detail screen.
///
/// The detail screen renders [crumbs], so a test can tap an ancestor crumb from
/// the deepest route in a realistic drill-down flow.
Future<void> _pumpApp(
  WidgetTester tester, {
  required ButtonOptions ancestor,
  _RouteRecorder? observer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [?observer],
      routes: {
        '/': (context) => const Scaffold(body: Text('home')),
        '/list': (context) => const Scaffold(body: Text('list')),
        '/detail': (context) => Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Breadcrumbs(buttons: _crumbs(ancestor)),
          ),
        ),
      },
    ),
  );
}

/// Pushes [route] on top of the current stack and settles the navigation.
Future<void> _open(
  WidgetTester tester,
  String route, {
  required NavigatorState navigator,
}) async {
  navigator.pushNamed(route);
  await tester.pumpAndSettle();
}

/// The navigator driving the app pumped by [_pumpApp].
NavigatorState _navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator));

void main() {
  group('Breadcrumbs', () {
    group('back navigation', () {
      testWidgets('should pop the ancestor crumb onto its own route', (
        WidgetTester tester,
      ) async {
        // Arrange
        final observer = _RouteRecorder();
        await _pumpApp(
          tester,
          ancestor: ButtonOptions(
            label: 'List',
            path: '/list',
            back: true,
            onTap: () {},
          ),
          observer: observer,
        );
        final navigator = _navigator(tester);
        await _open(tester, '/list', navigator: navigator);
        await _open(tester, '/detail', navigator: navigator);
        expect(observer.history, ['/', '/list', '/detail']);

        // Act
        await tester.tap(find.widgetWithText(ActionChip, 'List'));
        await tester.pumpAndSettle();

        // Assert
        expect(observer.history, ['/', '/list']);
        expect(find.text('list'), findsOneWidget);
        expect(find.text('home'), findsNothing);
      });

      testWidgets('should let the system back button return to the list', (
        WidgetTester tester,
      ) async {
        // Arrange
        final observer = _RouteRecorder();
        await _pumpApp(
          tester,
          ancestor: ButtonOptions(
            label: 'List',
            path: '/list',
            back: true,
            onTap: () {},
          ),
          observer: observer,
        );
        final navigator = _navigator(tester);
        await _open(tester, '/list', navigator: navigator);
        await _open(tester, '/detail', navigator: navigator);

        // Act
        await tester.tap(find.widgetWithText(ActionChip, 'List'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('home'), findsOneWidget);
        expect(observer.history, ['/']);
      });

      testWidgets('should ignore the crumb path when popping back', (
        WidgetTester tester,
      ) async {
        // Arrange
        // Real trails carry query parameters in the crumb path, and the anchor
        // they point at already sits on the stack.
        final observer = _RouteRecorder();
        await _pumpApp(
          tester,
          ancestor: ButtonOptions(
            label: 'List',
            path: '/list?filter=open',
            back: true,
            onTap: () {},
          ),
          observer: observer,
        );
        final navigator = _navigator(tester);
        await _open(tester, '/list', navigator: navigator);
        await _open(tester, '/detail', navigator: navigator);

        // Act
        await tester.tap(find.widgetWithText(ActionChip, 'List'));
        await tester.pumpAndSettle();

        // Assert
        expect(observer.history, ['/', '/list']);
        expect(find.text('list'), findsOneWidget);
      });

      testWidgets('should push the crumb target on a deep linked route', (
        WidgetTester tester,
      ) async {
        // Arrange
        // A deep link can surface `/detail` as a route with nothing beneath it,
        // so there is no history entry to pop back to.
        final observer = _RouteRecorder();

        Widget detail(BuildContext context) => Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Column(
              children: [
                const Text('detail'),
                Breadcrumbs(
                  buttons: _crumbs(
                    ButtonOptions(
                      label: 'List',
                      path: '/list',
                      back: true,
                      onTap: () {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [observer],
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => settings.name == '/detail'
                  ? detail(context)
                  : const Scaffold(body: Text('list')),
            ),
            onGenerateInitialRoutes: (initialRoute) => [
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/detail'),
                builder: detail,
              ),
            ],
          ),
        );
        final navigator = _navigator(tester);
        expect(navigator.canPop(), isFalse);

        // Act
        await tester.tap(find.widgetWithText(ActionChip, 'List'));
        await tester.pumpAndSettle();

        // Assert
        // Nothing could be popped, so the crumb target is pushed and the browser
        // and system back button return to the deep linked detail screen.
        expect(observer.history, ['/detail', '/list']);
        expect(find.text('list'), findsOneWidget);
        expect(navigator.canPop(), isTrue);

        // Act
        navigator.pop();
        await tester.pumpAndSettle();

        // Assert
        expect(observer.history, ['/detail']);
        expect(find.text('detail'), findsOneWidget);
      });

      testWidgets('should keep replacing the route when back is not set', (
        WidgetTester tester,
      ) async {
        // Arrange
        final observer = _RouteRecorder();
        await _pumpApp(
          tester,
          ancestor: ButtonOptions(label: 'List', path: '/list', onTap: () {}),
          observer: observer,
        );
        final navigator = _navigator(tester);
        await _open(tester, '/list', navigator: navigator);
        await _open(tester, '/detail', navigator: navigator);
        expect(observer.history, ['/', '/list', '/detail']);

        // Act
        await tester.tap(find.widgetWithText(ActionChip, 'List'));
        await tester.pumpAndSettle();

        // Assert
        // The default stays destructive on purpose: `/detail` is replaced by a
        // redirected `/list`, so it is no longer in the history at all.
        expect(observer.history, ['/', '/list', '/list']);
        expect(find.text('list'), findsOneWidget);
        expect(navigator.canPop(), isTrue);
      });

      testWidgets('should ignore back when pop selects replacement', (
        WidgetTester tester,
      ) async {
        // Arrange
        final observer = _RouteRecorder();
        await _pumpApp(
          tester,
          ancestor: ButtonOptions(
            label: 'List',
            path: '/list',
            pop: true,
            back: true,
            onTap: () {},
          ),
          observer: observer,
        );
        final navigator = _navigator(tester);
        await _open(tester, '/list', navigator: navigator);
        await _open(tester, '/detail', navigator: navigator);

        // Act
        await tester.tap(find.widgetWithText(ActionChip, 'List'));
        await tester.pumpAndSettle();

        // Assert
        // `pop` owns redirect style replacement, so `back` does not change it.
        expect(observer.history, ['/', '/list', '/list']);
        expect(find.text('list'), findsOneWidget);
        expect(navigator.canPop(), isTrue);
      });

      testWidgets('should still run onTap before going back', (
        WidgetTester tester,
      ) async {
        // Arrange
        var taps = 0;
        await _pumpApp(
          tester,
          ancestor: ButtonOptions(
            label: 'List',
            path: '/list',
            back: true,
            onTap: () => taps++,
          ),
        );
        final navigator = _navigator(tester);
        await _open(tester, '/list', navigator: navigator);
        await _open(tester, '/detail', navigator: navigator);

        // Act
        await tester.tap(find.widgetWithText(ActionChip, 'List'));
        await tester.pumpAndSettle();

        // Assert
        expect(taps, 1);
      });
    });
  });
}
