import 'package:fabric_flutter/component/input_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside a minimal [MaterialApp] so localization and theme are
/// available to [InputData] without requiring full Firebase bootstrap.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

/// Pumps [builder] at the named [route] so [ModalRoute.of] inside [InputData]
/// resolves the route name for auto-generated [automationKey] values.
Future<void> _pumpWithRoute(
  WidgetTester tester, {
  required String route,
  required Widget Function(BuildContext) builder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      initialRoute: route,
      routes: {route: builder},
    ),
  );
  await tester.pump();
}

/// Pumps [child] inside an unnamed [MaterialPageRoute].
///
/// This exercises the automation-key fallback branch where [ModalRoute]
/// resolves to a route whose name is absent or empty instead of `/`.
Future<void> _pumpWithUnnamedRoute(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Navigator(
        onGenerateInitialRoutes: (_, __) => <Route<void>>[
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: ''),
            builder: (_) => Scaffold(body: child),
          ),
        ],
      ),
    ),
  );
  await tester.pump();
}

/// Retrieves the outermost [Semantics] node that has [container] set to `true`.
Semantics _findContainer(WidgetTester tester) {
  return tester
      .widgetList<Semantics>(find.byType(Semantics))
      .firstWhere((s) => s.container == true);
}

void main() {
  group('InputData', () {
    group('semanticsLabel', () {
      testWidgets('should use explicit semanticsLabel when provided', (
        WidgetTester tester,
      ) async {
        // Arrange
        const explicitLabel = 'Custom Email Label';

        // Act
        await _pump(
          tester,
          InputData(
            value: '',
            type: InputDataType.email,
            label: 'Email',
            semanticsLabel: explicitLabel,
          ),
        );

        // Assert
        final node = _findContainer(tester);
        expect(node.properties.label, equals(explicitLabel));
      });

      testWidgets('should fall back to label when semanticsLabel is null', (
        WidgetTester tester,
      ) async {
        // Arrange
        const widgetLabel = 'Email Address';

        // Act
        await _pump(
          tester,
          InputData(value: '', type: InputDataType.email, label: widgetLabel),
        );

        // Assert
        final node = _findContainer(tester);
        expect(node.properties.label, equals(widgetLabel));
      });

      testWidgets(
        'should fall back to localized type name for email when label is null',
        (WidgetTester tester) async {
          // Arrange – no label, no semanticsLabel

          // Act
          await _pump(
            tester,
            InputData(value: '', type: InputDataType.email),
          );

          // Assert – AppLocalizations returns 'Email' for 'label--email'
          final node = _findContainer(tester);
          expect(node.properties.label, isNotNull);
          expect(node.properties.label, isNotEmpty);
        },
      );

      testWidgets(
        'should fall back to localized type name for phone when label is null',
        (WidgetTester tester) async {
          // Arrange

          // Act
          await _pump(
            tester,
            InputData(value: '', type: InputDataType.phone),
          );

          // Assert – 'label--phone-number' resolves to a non-empty string
          final node = _findContainer(tester);
          expect(node.properties.label, isNotNull);
          expect(node.properties.label, isNotEmpty);
        },
      );

      testWidgets(
        'should fall back to localized type name for date when label is null',
        (WidgetTester tester) async {
          // Arrange

          // Act
          await _pump(
            tester,
            InputData(value: null, type: InputDataType.date),
          );

          // Assert – 'label--date' resolves to a non-empty string
          final node = _findContainer(tester);
          expect(node.properties.label, isNotNull);
          expect(node.properties.label, isNotEmpty);
        },
      );

      testWidgets(
        'should fall back to localized type name for secret when label is null',
        (WidgetTester tester) async {
          // Arrange

          // Act
          await _pump(
            tester,
            InputData(value: '', type: InputDataType.secret),
          );

          // Assert – 'label--password' resolves to a non-empty string
          final node = _findContainer(tester);
          expect(node.properties.label, isNotNull);
          expect(node.properties.label, isNotEmpty);
        },
      );

      testWidgets(
        'should return null label for string type when no label is set',
        (WidgetTester tester) async {
          // Arrange

          // Act
          await _pump(
            tester,
            InputData(value: '', type: InputDataType.string),
          );

          // Assert – string type has no type-level fallback label
          final node = _findContainer(tester);
          expect(node.properties.label, isNull);
        },
      );
    });

    group('automationKey', () {
      testWidgets('should use explicit automationKey unchanged when provided', (
        WidgetTester tester,
      ) async {
        // Arrange
        const key = 'profile_form_input_email';

        // Act
        await _pump(
          tester,
          InputData(
            value: '',
            type: InputDataType.email,
            automationKey: key,
          ),
        );

        // Assert
        final node = _findContainer(tester);
        expect(node.properties.identifier, equals(key));
      });

      testWidgets(
        'should auto-generate key following [route]_[label]_input_[type]',
        (WidgetTester tester) async {
          // Arrange – named route '/profile' with label 'Email'

          // Act
          await _pumpWithRoute(
            tester,
            route: '/profile',
            builder: (context) => Scaffold(
              body: InputData(
                value: '',
                type: InputDataType.email,
                label: 'Email',
              ),
            ),
          );

          // Assert – route 'profile', contextBlock 'email', type 'email'
          final node = _findContainer(tester);
          expect(
            node.properties.identifier,
            equals('profile_email_input_email'),
          );
        },
      );

      testWidgets(
        'should sanitize multi-segment route into underscore-separated slug',
        (WidgetTester tester) async {
          // Arrange – route '/settings/account'

          // Act
          await _pumpWithRoute(
            tester,
            route: '/settings/account',
            builder: (context) => Scaffold(
              body: InputData(
                value: '',
                type: InputDataType.phone,
                label: 'Phone',
              ),
            ),
          );

          // Assert – 'settings/account' → 'settings_account'
          final node = _findContainer(tester);
          expect(
            node.properties.identifier,
            equals('settings_account_phone_input_phone'),
          );
        },
      );

      testWidgets(
        'should use root as route segment when route is /',
        (WidgetTester tester) async {
          // Arrange

          // Act
          await _pumpWithRoute(
            tester,
            route: '/',
            builder: (context) => Scaffold(
              body: InputData(value: '', type: InputDataType.string),
            ),
          );

          // Assert
          final node = _findContainer(tester);
          final id = node.properties.identifier;
          expect(id, isNotNull);
          expect(id, startsWith('root_'));
        },
      );

      testWidgets(
        'should fall back to type name as contextBlock when no label is set',
        (WidgetTester tester) async {
          // Arrange – no label, route '/form'

          // Act
          await _pumpWithRoute(
            tester,
            route: '/form',
            builder: (context) => Scaffold(
              body: InputData(value: '', type: InputDataType.int),
            ),
          );

          // Assert – contextBlock = 'int', type = 'int'
          final node = _findContainer(tester);
          expect(
            node.properties.identifier,
            equals('form_int_input_int'),
          );
        },
      );

      testWidgets(
        'should fall back to app as route segment when no route name exists',
        (WidgetTester tester) async {
          // Arrange – the nearest route name is intentionally empty

          // Act
          await _pumpWithUnnamedRoute(
            tester,
            InputData(value: '', type: InputDataType.string, label: 'Name'),
          );

          // Assert – falls back to 'app' as route segment
          final node = _findContainer(tester);
          expect(node.properties.identifier, isNotNull);
          expect(node.properties.identifier, equals('app_name_input_string'));
        },
      );
    });

    group('semanticHint', () {
      testWidgets('should use explicit semanticHint when provided', (
        WidgetTester tester,
      ) async {
        // Arrange
        const hint = 'Agent: use ISO 8601 format';

        // Act
        await _pump(
          tester,
          InputData(
            value: '',
            type: InputDataType.string,
            semanticHint: hint,
          ),
        );

        // Assert
        final node = _findContainer(tester);
        expect(node.properties.hint, equals(hint));
      });

      testWidgets(
        'should infer email format hint for InputDataType.email',
        (WidgetTester tester) async {
          // Arrange

          // Act
          await _pump(
            tester,
            InputData(value: '', type: InputDataType.email),
          );

          // Assert
          final node = _findContainer(tester);
          expect(
            node.properties.hint,
            equals('Enter a valid email address, e.g. user@example.com'),
          );
        },
      );

      testWidgets(
        'should infer phone format hint for InputDataType.phone',
        (WidgetTester tester) async {
          // Arrange

          // Act
          await _pump(
            tester,
            InputData(value: '', type: InputDataType.phone),
          );

          // Assert
          final node = _findContainer(tester);
          expect(
            node.properties.hint,
            equals('Enter a phone number with country code, e.g. +12223334444'),
          );
        },
      );

      testWidgets(
        'should infer URL format hint for InputDataType.url',
        (WidgetTester tester) async {
          // Arrange

          // Act
          await _pump(
            tester,
            InputData(value: '', type: InputDataType.url),
          );

          // Assert
          final node = _findContainer(tester);
          expect(
            node.properties.hint,
            equals('Enter a valid URL starting with https://'),
          );
        },
      );

      testWidgets(
        'should infer date picker hint for InputDataType.date',
        (WidgetTester tester) async {
          // Arrange

          // Act
          await _pump(
            tester,
            InputData(value: null, type: InputDataType.date),
          );

          // Assert
          final node = _findContainer(tester);
          expect(
            node.properties.hint,
            equals('Select a date using the calendar picker'),
          );
        },
      );

      testWidgets(
        'should infer bool toggle hint for InputDataType.bool',
        (WidgetTester tester) async {
          // Arrange

          // Act
          await _pump(
            tester,
            InputData(value: false, type: InputDataType.bool),
          );

          // Assert
          final node = _findContainer(tester);
          expect(
            node.properties.hint,
            equals('Toggle to enable or disable this option'),
          );
        },
      );

      testWidgets(
        'should infer list selection hint for InputDataType.dropdown',
        (WidgetTester tester) async {
          // Arrange

          // Act
          await _pump(
            tester,
            InputData(value: null, type: InputDataType.dropdown),
          );

          // Assert
          final node = _findContainer(tester);
          expect(
            node.properties.hint,
            equals('Select one option from the list'),
          );
        },
      );

      testWidgets(
        'should return null hint for generic string type',
        (WidgetTester tester) async {
          // Arrange

          // Act
          await _pump(
            tester,
            InputData(value: '', type: InputDataType.string),
          );

          // Assert – string has no type-specific format constraint
          final node = _findContainer(tester);
          expect(node.properties.hint, isNull);
        },
      );

      testWidgets(
        'should return null hint for generic text type',
        (WidgetTester tester) async {
          // Arrange

          // Act
          await _pump(
            tester,
            InputData(value: '', type: InputDataType.text),
          );

          // Assert
          final node = _findContainer(tester);
          expect(node.properties.hint, isNull);
        },
      );
    });
  });
}
