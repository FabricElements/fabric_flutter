import 'package:fabric_flutter/helper/agent/agent_authorizer.dart';
import 'package:fabric_flutter/helper/agent/agent_bridge.dart';
import 'package:fabric_flutter/helper/agent/agent_command.dart';
import 'package:fabric_flutter/helper/agent/agent_element.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/helper/agent/agent_exception.dart';
import 'package:fabric_flutter/helper/agent/agent_navigator_observer.dart';
import 'package:fabric_flutter/helper/app_global.dart';
import 'package:fabric_flutter/serialized/agent_element_snapshot.dart';
import 'package:fabric_flutter/serialized/agent_request.dart';
import 'package:fabric_flutter/serialized/agent_route_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Denies every request with a fixed message.
///
/// Stands in for the authentication layer that is stacked on top of this core
/// so the seam can be exercised without implementing real access control here.
class _DenyAllAuthorizer extends AgentAuthorizer {
  const _DenyAllAuthorizer();

  @override
  AgentAuthorization authorize(AgentRequest request, {AgentCommand? command}) =>
      const AgentAuthorization.deny('Nope.');
}

/// Approves every request while attaching the caller's role to the context.
class _RoleAuthorizer extends AgentAuthorizer {
  const _RoleAuthorizer(this.role);

  /// Stores the role handed to the command handler.
  final String role;

  @override
  AgentAuthorization authorize(AgentRequest request, {AgentCommand? command}) {
    if (command?.requiresRole != null && command!.requiresRole != role) {
      return AgentAuthorization.deny('Requires ${command.requiresRole}.');
    }
    return AgentAuthorization.allow(meta: {'role': role});
  }
}

/// Builds an enabled bridge backed by an isolated element index.
AgentBridge _bridge({
  AgentElementIndex? index,
  AgentAuthorizer? authorizer,
  AgentNavigatorObserver? observer,
}) {
  final bridge = AgentBridge(
    elements: index ?? AgentElementIndex(),
    navigatorObserver: observer ?? AgentNavigatorObserver(),
  );
  bridge.configure(
    enabled: true,
    appName: 'Fabric',
    appVersion: '1.0.0',
    authorizer: authorizer,
    routes: [AgentRouteInfo(name: '/dashboard', title: 'Dashboard')],
  );
  return bridge;
}

/// Builds a request map addressed to [method].
Map<String, dynamic> _request(
  String method, {
  String id = '1',
  Map<String, dynamic>? params,
}) => <String, dynamic>{'id': id, 'method': method, 'params': params};

/// Builds an invoke request for [commandId].
Map<String, dynamic> _invoke(
  String commandId, {
  Map<String, dynamic>? params,
  int? timeoutMs,
}) => _request(
  'invoke',
  params: <String, dynamic>{
    'commandId': commandId,
    'params': ?params,
    'timeoutMs': ?timeoutMs,
  },
);

void main() {
  group('AgentBridge', () {
    group('enabled', () {
      test('should be disabled until a host opts in', () async {
        // Arrange
        final bridge = AgentBridge(elements: AgentElementIndex());

        // Act
        final response = await bridge.handle(_request('ping'));

        // Assert
        expect(bridge.enabled, isFalse);
        expect(response['ok'], isFalse);
        expect((response['error'] as Map)['code'], 'disabled');
      });

      test('should serve requests once configured', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(_request('ping'));

        // Assert
        expect(response['ok'], isTrue);
        expect((response['result'] as Map)['pong'], isTrue);
        expect((response['result'] as Map)['app'], 'Fabric');
      });

      test('should return to a disabled state after reset', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        bridge.reset();
        final response = await bridge.handle(_request('ping'));

        // Assert
        expect(bridge.registry.length, 0);
        expect((response['error'] as Map)['code'], 'disabled');
      });
    });

    group('describe', () {
      test('should publish the app, routes, and command catalog', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(_request('describe'));
        final result = response['result'] as Map;

        // Assert
        expect(result['app'], 'Fabric');
        expect(result['version'], '1.0.0');
        expect((result['routes'] as List).single['name'], '/dashboard');
        final ids = (result['commands'] as List)
            .map((command) => (command as Map)['id'])
            .toList();
        expect(
          ids,
          containsAll(<String>[
            'navigate',
            'set_value',
            'tap',
            'read_value',
            'wait_for',
            'screen_state',
            'list_commands',
          ]),
        );
      });

      test('should include host commands with their required role', () async {
        // Arrange
        final bridge = _bridge();
        bridge.registry.register(
          AgentCommand.define(
            id: 'archive_order',
            title: 'Archive order',
            requiresRole: 'admin',
            handler: (context) => null,
          ),
        );

        // Act
        final response = await bridge.handle(_request('describe'));
        final commands = (response['result'] as Map)['commands'] as List;

        // Assert
        expect(
          commands.any(
            (command) =>
                (command as Map)['id'] == 'archive_order' &&
                command['requiresRole'] == 'admin',
          ),
          isTrue,
        );
      });
    });

    group('methods', () {
      test('should reject an unknown method with not_found', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(_request('explode'));

        // Assert
        expect((response['error'] as Map)['code'], 'not_found');
      });

      test('should reject a missing method with invalid_params', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(<String, dynamic>{'id': '1'});

        // Assert
        expect((response['error'] as Map)['code'], 'invalid_params');
      });

      test('should tolerate a null request', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(null);

        // Assert
        expect(response['ok'], isFalse);
        expect((response['error'] as Map)['code'], 'invalid_params');
      });
    });

    group('state', () {
      test('should report the indexed elements', () async {
        // Arrange
        final index = AgentElementIndex();
        index.register(
          AgentElementHandle(
            id: 'home_toolbar_button_save',
            type: AgentElementType.button,
            label: 'Save',
            hint: 'Saves the form',
          ),
        );
        final bridge = _bridge(index: index);

        // Act
        final response = await bridge.handle(_request('state'));
        final elements = (response['result'] as Map)['elements'] as List;

        // Assert
        expect(elements.single['id'], 'home_toolbar_button_save');
        expect(elements.single['type'], 'button');
        expect(elements.single['label'], 'Save');
        expect(elements.single['hint'], 'Saves the form');
        expect(elements.single['enabled'], isTrue);
      });

      test('should match the screen_state command output', () async {
        // Arrange
        final index = AgentElementIndex()
          ..register(AgentElementHandle(id: 'a'));
        final bridge = _bridge(index: index);

        // Act
        final state = await bridge.handle(_request('state'));
        final command = await bridge.handle(_invoke('screen_state'));

        // Assert
        expect(command['result'], state['result']);
      });
    });

    group('invoke', () {
      test('should run a registered host command', () async {
        // Arrange
        final bridge = _bridge();
        bridge.registry.register(
          AgentCommand.define(
            id: 'echo',
            title: 'Echo',
            handler: (context) => {'said': context['message']},
          ),
        );

        // Act
        final response = await bridge.handle(
          _invoke('echo', params: {'message': 'hi'}),
        );

        // Assert
        expect(response['ok'], isTrue);
        expect((response['result'] as Map)['said'], 'hi');
      });

      test('should require a commandId', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(_request('invoke'));

        // Assert
        expect((response['error'] as Map)['code'], 'invalid_params');
      });

      test('should reject an unknown command with not_found', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(_invoke('missing'));

        // Assert
        expect((response['error'] as Map)['code'], 'not_found');
      });

      test('should reject non-map params with invalid_params', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(
          _request(
            'invoke',
            params: <String, dynamic>{
              'commandId': 'screen_state',
              'params': 'nope',
            },
          ),
        );

        // Assert
        expect((response['error'] as Map)['code'], 'invalid_params');
      });

      test('should report a thrown handler as failed', () async {
        // Arrange
        final bridge = _bridge();
        bridge.registry.register(
          AgentCommand.define(
            id: 'boom',
            title: 'Boom',
            handler: (context) => throw StateError('kaboom'),
          ),
        );

        // Act
        final response = await bridge.handle(_invoke('boom'));

        // Assert
        expect((response['error'] as Map)['code'], 'failed');
        expect((response['error'] as Map)['message'], contains('kaboom'));
      });

      test('should honor an AgentException code thrown by a handler', () async {
        // Arrange
        final bridge = _bridge();
        bridge.registry.register(
          AgentCommand.define(
            id: 'missing_record',
            title: 'Missing record',
            handler: (context) => throw AgentException.notFound('gone'),
          ),
        );

        // Act
        final response = await bridge.handle(_invoke('missing_record'));

        // Assert
        expect((response['error'] as Map)['code'], 'not_found');
        expect((response['error'] as Map)['message'], 'gone');
      });

      test('should fail a command that exceeds its timeout', () async {
        // Arrange
        final bridge = _bridge();
        bridge.registry.register(
          AgentCommand.define(
            id: 'slow',
            title: 'Slow',
            handler: (context) =>
                Future<void>.delayed(const Duration(seconds: 5)),
          ),
        );

        // Act
        final response = await bridge.handle(_invoke('slow', timeoutMs: 20));

        // Assert
        expect((response['error'] as Map)['code'], 'failed');
        expect((response['error'] as Map)['message'], contains('timed out'));
      });

      test('should echo the request id back on every response', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(_request('ping', id: 'abc'));

        // Assert
        expect(response['id'], 'abc');
      });
    });

    group('authorizer', () {
      test('should deny a request with the authorizer message', () async {
        // Arrange
        final bridge = _bridge(authorizer: const _DenyAllAuthorizer());

        // Act
        final response = await bridge.handle(_request('describe'));

        // Assert
        expect((response['error'] as Map)['code'], 'unauthorized');
        expect((response['error'] as Map)['message'], 'Nope.');
      });

      test('should deny a command whose required role is missing', () async {
        // Arrange
        final bridge = _bridge(authorizer: const _RoleAuthorizer('viewer'));
        bridge.registry.register(
          AgentCommand.define(
            id: 'archive_order',
            title: 'Archive order',
            requiresRole: 'admin',
            handler: (context) => 'done',
          ),
        );

        // Act
        final response = await bridge.handle(_invoke('archive_order'));

        // Assert
        expect((response['error'] as Map)['code'], 'unauthorized');
        expect((response['error'] as Map)['message'], 'Requires admin.');
      });

      test('should forward authorizer metadata to the handler', () async {
        // Arrange
        final bridge = _bridge(authorizer: const _RoleAuthorizer('admin'));
        bridge.registry.register(
          AgentCommand.define(
            id: 'whoami',
            title: 'Who am I',
            handler: (context) => context.meta['role'],
          ),
        );

        // Act
        final response = await bridge.handle(_invoke('whoami'));

        // Assert
        expect(response['result'], 'admin');
      });
    });

    group('built-in commands', () {
      test('list_commands should list every command', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(_invoke('list_commands'));

        // Assert
        expect((response['result'] as List).length, bridge.registry.length);
      });

      test('list_commands should filter by category', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(
          _invoke('list_commands', params: {'category': 'interaction'}),
        );
        final ids = (response['result'] as List)
            .map((command) => (command as Map)['id'])
            .toList();

        // Assert
        expect(ids, containsAll(<String>['set_value', 'tap']));
        expect(ids, isNot(contains('navigate')));
      });

      test('read_value should return a single element snapshot', () async {
        // Arrange
        final index = AgentElementIndex()
          ..register(
            AgentElementHandle(
              id: 'profile_form_input_email',
              type: AgentElementType.textInput,
              valueGetter: () => 'user@example.com',
            ),
          );
        final bridge = _bridge(index: index);

        // Act
        final response = await bridge.handle(
          _invoke(
            'read_value',
            params: {'elementId': 'profile_form_input_email'},
          ),
        );

        // Assert
        expect((response['result'] as Map)['value'], 'user@example.com');
        expect((response['result'] as Map)['type'], 'text_input');
      });

      test('read_value should fail with not_found for an unknown id', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(
          _invoke('read_value', params: {'elementId': 'missing'}),
        );

        // Assert
        expect((response['error'] as Map)['code'], 'not_found');
      });

      test('read_value should require an elementId', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(_invoke('read_value'));

        // Assert
        expect((response['error'] as Map)['code'], 'invalid_params');
      });

      test('set_value should apply the value through the setter', () async {
        // Arrange
        var stored = 'before';
        final index = AgentElementIndex()
          ..register(
            AgentElementHandle(
              id: 'input',
              type: AgentElementType.textInput,
              valueGetter: () => stored,
              setter: (value) => stored = value.toString(),
            ),
          );
        final bridge = _bridge(index: index);

        // Act
        final response = await bridge.handle(
          _invoke(
            'set_value',
            params: {'elementId': 'input', 'value': 'after'},
          ),
        );

        // Assert
        expect(stored, 'after');
        expect((response['result'] as Map)['value'], 'after');
      });

      test('set_value should fail when the element has no setter', () async {
        // Arrange
        final index = AgentElementIndex()
          ..register(AgentElementHandle(id: 'button'));
        final bridge = _bridge(index: index);

        // Act
        final response = await bridge.handle(
          _invoke('set_value', params: {'elementId': 'button', 'value': 'a'}),
        );

        // Assert
        expect((response['error'] as Map)['code'], 'failed');
      });

      test('set_value should fail when the element is disabled', () async {
        // Arrange
        final index = AgentElementIndex()
          ..register(
            AgentElementHandle(
              id: 'input',
              enabledGetter: () => false,
              setter: (value) {},
            ),
          );
        final bridge = _bridge(index: index);

        // Act
        final response = await bridge.handle(
          _invoke('set_value', params: {'elementId': 'input', 'value': 'a'}),
        );

        // Assert
        expect((response['error'] as Map)['message'], contains('disabled'));
      });

      test('tap should activate the element', () async {
        // Arrange
        var taps = 0;
        final index = AgentElementIndex()
          ..register(
            AgentElementHandle(
              id: 'save',
              type: AgentElementType.button,
              activator: () => taps++,
            ),
          );
        final bridge = _bridge(index: index);

        // Act
        final response = await bridge.handle(
          _invoke('tap', params: {'elementId': 'save'}),
        );

        // Assert
        expect(taps, 1);
        expect((response['result'] as Map)['tapped'], isTrue);
      });

      test('tap should fail when the element cannot be tapped', () async {
        // Arrange
        final index = AgentElementIndex()
          ..register(AgentElementHandle(id: 'label'));
        final bridge = _bridge(index: index);

        // Act
        final response = await bridge.handle(
          _invoke('tap', params: {'elementId': 'label'}),
        );

        // Assert
        expect((response['error'] as Map)['code'], 'failed');
      });

      test('tap should fail with not_found for an unknown element', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(
          _invoke('tap', params: {'elementId': 'ghost'}),
        );

        // Assert
        expect((response['error'] as Map)['code'], 'not_found');
      });

      test(
        'wait_for should return as soon as the element is visible',
        () async {
          // Arrange
          final index = AgentElementIndex();
          final bridge = _bridge(index: index);
          Future<void>.delayed(
            const Duration(milliseconds: 30),
            () => index.register(AgentElementHandle(id: 'late')),
          );

          // Act
          final response = await bridge.handle(
            _invoke(
              'wait_for',
              params: {'elementId': 'late', 'timeoutMs': 2000},
            ),
          );

          // Assert
          expect(response['ok'], isTrue);
          expect((response['result'] as Map)['matched'], isTrue);
        },
      );

      test('wait_for should match an expected value', () async {
        // Arrange
        var current = 'a';
        final index = AgentElementIndex()
          ..register(
            AgentElementHandle(id: 'input', valueGetter: () => current),
          );
        final bridge = _bridge(index: index);
        Future<void>.delayed(
          const Duration(milliseconds: 30),
          () => current = 'b',
        );

        // Act
        final response = await bridge.handle(
          _invoke(
            'wait_for',
            params: {'elementId': 'input', 'value': 'b', 'timeoutMs': 2000},
          ),
        );

        // Assert
        expect((response['result'] as Map)['condition'], 'value');
      });

      test('wait_for should fail when the timeout elapses', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(
          _invoke('wait_for', params: {'elementId': 'ghost', 'timeoutMs': 40}),
        );

        // Assert
        expect((response['error'] as Map)['code'], 'failed');
        expect((response['error'] as Map)['message'], contains('Timed out'));
      });

      test('wait_for should require an element or a route', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(_invoke('wait_for'));

        // Assert
        expect((response['error'] as Map)['code'], 'invalid_params');
      });

      test('wait_for should reject an unknown condition', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(
          _invoke(
            'wait_for',
            params: {'elementId': 'a', 'condition': 'sideways'},
          ),
        );

        // Assert
        expect((response['error'] as Map)['code'], 'invalid_params');
      });

      test(
        'wait_for should satisfy absent for an element never indexed',
        () async {
          // Arrange
          final bridge = _bridge();

          // Act
          final response = await bridge.handle(
            _invoke(
              'wait_for',
              params: {'elementId': 'ghost', 'condition': 'absent'},
            ),
          );

          // Assert
          expect(response['ok'], isTrue);
        },
      );
    });

    group('navigate', () {
      testWidgets('should push a named route', (WidgetTester tester) async {
        // Arrange
        final observer = AgentNavigatorObserver();
        final bridge = _bridge(observer: observer);
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: AppGlobal.navigatorKey,
            navigatorObservers: [observer],
            initialRoute: '/',
            routes: {
              '/': (context) => const Text('home'),
              '/second': (context) => const Text('second'),
            },
          ),
        );

        // Act
        final response = await bridge.handle(
          _invoke('navigate', params: {'route': '/second'}),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(response['ok'], isTrue);
        expect(find.text('second'), findsOneWidget);
        expect(observer.routeName, '/second');
        expect(bridge.state().route, '/second');
      });

      testWidgets('should replace the current route when asked', (
        WidgetTester tester,
      ) async {
        // Arrange
        final observer = AgentNavigatorObserver();
        final bridge = _bridge(observer: observer);
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: AppGlobal.navigatorKey,
            navigatorObservers: [observer],
            initialRoute: '/',
            routes: {
              '/': (context) => const Text('home'),
              '/second': (context) => const Text('second'),
            },
          ),
        );

        // Act
        final response = await bridge.handle(
          _invoke('navigate', params: {'route': '/second', 'replace': true}),
        );
        await tester.pumpAndSettle();

        // Assert
        expect((response['result'] as Map)['replaced'], isTrue);
        expect(find.text('second'), findsOneWidget);
      });

      test('should require a route parameter', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final response = await bridge.handle(_invoke('navigate'));

        // Assert
        expect((response['error'] as Map)['code'], 'invalid_params');
      });
    });
  });
}
