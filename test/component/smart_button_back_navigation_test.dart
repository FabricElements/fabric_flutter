import 'package:fabric_flutter/component/smart_button.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the named routes the navigator has mounted.
///
/// Pushing a route appends it and popping removes the top-most match, so the
/// list shows which screens a back button can still reach. A redirect-style
/// replacement pops the route it leaves before pushing its target, which is why
/// the departed name disappears from the list.
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
    // A route always leaves from the top of the stack, so drop the last match
    // rather than the first.
    final name = route.settings.name;
    if (name == null) return;
    final index = history.lastIndexOf(name);
    if (index >= 0) history.removeAt(index);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final index = history.indexOf(oldRoute?.settings.name ?? '');
    if (index >= 0) history[index] = newRoute!.settings.name!;
  }
}

/// Pumps [button] on `/detail`, with `/list` already below it in the stack.
Future<void> _pumpApp(
  WidgetTester tester, {
  required ButtonOptions button,
  bool pop = false,
  List<dynamic>? children,
  _RouteRecorder? observer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [?observer],
      routes: {
        '/': (context) => const Scaffold(body: Text('home')),
        '/list': (context) => const Scaffold(body: Text('list')),
        '/detail': (context) => Scaffold(
          body: SmartButton(button: button, children: children, pop: pop),
        ),
        '/next': (context) => const Scaffold(body: Text('next page')),
      },
    ),
  );
}

/// Pumps [button] on a `/detail` route that has nothing beneath it.
///
/// A deep link is the only way to reach this state; `MaterialApp` otherwise
/// always stacks `/` below the initial route.
Future<void> _pumpDeepLink(
  WidgetTester tester, {
  required ButtonOptions button,
  required _RouteRecorder observer,
}) async {
  Route<dynamic> route(RouteSettings settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (context) => settings.name == '/detail'
        ? Scaffold(body: SmartButton(button: button))
        : const Scaffold(body: Text('list')),
  );
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [observer],
      onGenerateRoute: route,
      onGenerateInitialRoutes: (initialRoute) => [
        route(const RouteSettings(name: '/detail')),
      ],
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

/// Invokes the popup menu's selection handler without opening the menu.
///
/// The rendered trigger is a button, so tapping it runs the primary action
/// instead of expanding the menu; the selection handler is the behaviour under
/// test here.
Future<void> _select(WidgetTester tester, String value) async {
  final menu = tester.widget<PopupMenuButton<String>>(
    find.byType(PopupMenuButton<String>),
  );
  menu.onSelected!(value);
  await tester.pumpAndSettle();
}

void main() {
  group('SmartButton', () {
    group('back navigation', () {
      testWidgets('should go back to the previous route when back is set', (
        WidgetTester tester,
      ) async {
        // Arrange
        final observer = _RouteRecorder();
        await _pumpApp(
          tester,
          button: ButtonOptions(label: 'List', path: '/list', back: true),
          observer: observer,
        );
        final navigator = _navigator(tester);
        await _open(tester, '/list', navigator: navigator);
        await _open(tester, '/detail', navigator: navigator);

        // Act
        await tester.tap(find.byType(SmartButton));
        await tester.pumpAndSettle();

        // Assert
        expect(observer.history, ['/', '/list']);
        expect(find.text('list'), findsOneWidget);
        expect(find.text('home'), findsNothing);
      });

      testWidgets('should open the path when there is no history to pop', (
        WidgetTester tester,
      ) async {
        // Arrange
        final observer = _RouteRecorder();
        await _pumpDeepLink(
          tester,
          button: ButtonOptions(label: 'List', path: '/list', back: true),
          observer: observer,
        );
        expect(_navigator(tester).canPop(), isFalse);

        // Act
        await tester.tap(find.byType(SmartButton));
        await tester.pumpAndSettle();

        // Assert
        expect(observer.history, ['/detail', '/list']);
        expect(find.text('list'), findsOneWidget);
      });

      testWidgets('should keep pushing when back is not set', (
        WidgetTester tester,
      ) async {
        // Arrange
        final observer = _RouteRecorder();
        await _pumpApp(
          tester,
          button: ButtonOptions(label: 'List', path: '/list'),
          observer: observer,
        );
        final navigator = _navigator(tester);
        await _open(tester, '/list', navigator: navigator);
        await _open(tester, '/detail', navigator: navigator);

        // Act
        await tester.tap(find.byType(SmartButton));
        await tester.pumpAndSettle();

        // Assert
        // The default is unchanged: the target is pushed on top of the stack, so
        // `/detail` is still reachable with the browser or system back button.
        expect(observer.history, ['/', '/list', '/detail', '/list']);
        expect(find.text('list'), findsOneWidget);
        expect(navigator.canPop(), isTrue);
      });

      testWidgets('should let pop override back', (WidgetTester tester) async {
        // Arrange
        final observer = _RouteRecorder();
        await _pumpApp(
          tester,
          pop: true,
          button: ButtonOptions(label: 'List', path: '/list', back: true),
          observer: observer,
        );
        final navigator = _navigator(tester);
        await _open(tester, '/list', navigator: navigator);
        await _open(tester, '/detail', navigator: navigator);

        // Act
        await tester.tap(find.byType(SmartButton));
        await tester.pumpAndSettle();

        // Assert
        expect(observer.history, isNot(contains('/detail')));
        expect(find.text('list'), findsOneWidget);
      });

      testWidgets('should still run onTap before going back', (
        WidgetTester tester,
      ) async {
        // Arrange
        var taps = 0;
        await _pumpApp(
          tester,
          button: ButtonOptions(
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
        await tester.tap(find.byType(SmartButton));
        await tester.pumpAndSettle();

        // Assert
        expect(taps, 1);
      });
    });

    group('popup menu back navigation', () {
      testWidgets('should go back when a menu entry sets back', (
        WidgetTester tester,
      ) async {
        // Arrange
        final observer = _RouteRecorder();
        await _pumpApp(
          tester,
          button: ButtonOptions(label: 'More'),
          children: [ButtonOptions(label: 'List', path: '/list', back: true)],
          observer: observer,
        );
        final navigator = _navigator(tester);
        await _open(tester, '/list', navigator: navigator);
        await _open(tester, '/detail', navigator: navigator);

        // Act
        await _select(tester, '/list');

        // Assert
        expect(observer.history, ['/', '/list']);
        expect(find.text('list'), findsOneWidget);
        expect(find.text('home'), findsNothing);
      });

      testWidgets('should push when a menu entry does not set back', (
        WidgetTester tester,
      ) async {
        // Arrange
        final observer = _RouteRecorder();
        await _pumpApp(
          tester,
          button: ButtonOptions(label: 'More'),
          children: [ButtonOptions(label: 'Next', path: '/next')],
          observer: observer,
        );
        final navigator = _navigator(tester);
        await _open(tester, '/list', navigator: navigator);
        await _open(tester, '/detail', navigator: navigator);

        // Act
        await _select(tester, '/next');

        // Assert
        expect(observer.history, ['/', '/list', '/detail', '/next']);
        expect(find.text('next page'), findsOneWidget);
      });

      testWidgets('should let the widget pop override a menu entry back', (
        WidgetTester tester,
      ) async {
        // Arrange
        final observer = _RouteRecorder();
        await _pumpApp(
          tester,
          pop: true,
          button: ButtonOptions(label: 'More'),
          children: [ButtonOptions(label: 'List', path: '/list', back: true)],
          observer: observer,
        );
        final navigator = _navigator(tester);
        await _open(tester, '/list', navigator: navigator);
        await _open(tester, '/detail', navigator: navigator);

        // Act
        await _select(tester, '/list');

        // Assert
        expect(observer.history, isNot(contains('/detail')));
        expect(find.text('list'), findsOneWidget);
      });
    });
  });
}
