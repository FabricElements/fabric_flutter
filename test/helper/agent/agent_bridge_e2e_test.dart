import 'package:fabric_flutter/helper/agent/agent_bridge.dart';
import 'package:fabric_flutter/helper/agent/agent_command.dart';
import 'package:fabric_flutter/helper/agent/agent_element_binding.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/helper/agent/agent_navigator_observer.dart';
import 'package:fabric_flutter/helper/agent/agent_transport.dart';
import 'package:fabric_flutter/helper/app_global.dart';
import 'package:fabric_flutter/serialized/agent_audit_record.dart';
import 'package:fabric_flutter/serialized/agent_element_snapshot.dart';
import 'package:fabric_flutter/serialized/agent_principal.dart';
import 'package:fabric_flutter/serialized/agent_route_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves the two tokens the end-to-end scenario authenticates with.
///
/// Stands in for the host application's token verification, which in a real
/// deployment asks the backend that issued the OAuth access token.
AgentPrincipal? _verify(String token) => switch (token) {
  'member-token' => AgentPrincipal(id: 'user-member', role: 'user'),
  'admin-token' => AgentPrincipal(id: 'user-admin', role: 'admin'),
  _ => null,
};

/// Renders a two-screen sample application wired to the agent bridge.
///
/// The screens publish their interactive widgets to [index] exactly as the
/// package components do, so the built-in commands can drive them.
class _SampleApp extends StatefulWidget {
  const _SampleApp({required this.index, required this.observer});

  /// Receives the elements published by this application.
  final AgentElementIndex index;

  /// Reports the active route to the bridge.
  final AgentNavigatorObserver observer;

  @override
  State<_SampleApp> createState() => _SampleAppState();
}

/// Owns the sample application's mutable form state.
class _SampleAppState extends State<_SampleApp> {
  /// Holds the value an agent writes through `set_value`.
  String _name = '';

  /// Counts how often the submit button was activated.
  int _submits = 0;

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: AppGlobal.navigatorKey,
    navigatorObservers: [widget.observer],
    initialRoute: '/',
    routes: <String, WidgetBuilder>{
      '/': (context) => Scaffold(
        body: Column(
          children: [
            AgentElement(
              index: widget.index,
              id: 'home_form_input_name',
              type: AgentElementType.textInput,
              label: 'Name',
              valueGetter: () => _name,
              setter: (value) => setState(() => _name = '${value ?? ''}'),
              child: Text('name:$_name'),
            ),
            AgentElement(
              index: widget.index,
              id: 'home_form_button_submit',
              type: AgentElementType.button,
              label: 'Submit',
              activator: () => setState(() => _submits++),
              child: Text('submits:$_submits'),
            ),
          ],
        ),
      ),
      '/settings': (context) =>
          const Scaffold(body: Center(child: Text('settings'))),
    },
  );
}

void main() {
  group('Agent bridge end to end', () {
    testWidgets('should drive a sample app through the in-process transport', (
      tester,
    ) async {
      // Arrange
      final index = AgentElementIndex();
      final observer = AgentNavigatorObserver();
      final bridge = AgentBridge(elements: index, navigatorObserver: observer);
      bridge.configure(
        enabled: true,
        appName: 'Sample',
        appVersion: '1.0.0',
        routes: [
          AgentRouteInfo(name: '/', title: 'Home'),
          AgentRouteInfo(name: '/settings', title: 'Settings'),
        ],
      );
      bridge.registry.register(
        AgentCommand.define(
          id: 'archive_order',
          title: 'Archive order',
          category: 'orders',
          requiresRole: 'admin',
          handler: (context) => <String, dynamic>{'archived': true},
        ),
      );
      final records = <AgentAuditRecord>[];
      final transport = await AgentInProcessTransport.start(
        bridge: bridge,
        verifier: _verify,
        auditSink: records.add,
      );
      await tester.pumpWidget(_SampleApp(index: index, observer: observer));
      await tester.pumpAndSettle();

      /// Sends [method] with [params] on behalf of [token].
      Future<Map<String, dynamic>> send(
        String method, {
        String? token,
        Map<String, dynamic>? params,
        String id = '1',
      }) => transport.send(<String, dynamic>{
        'id': id,
        'method': method,
        'params': <String, dynamic>{...?params, 'auth': ?token},
      });

      /// Invokes [commandId] on behalf of [token].
      Future<Map<String, dynamic>> invoke(
        String commandId, {
        String? token,
        Map<String, dynamic>? params,
      }) => send(
        'invoke',
        token: token,
        params: <String, dynamic>{'commandId': commandId, 'params': ?params},
      );

      // Act & Assert — an unauthenticated caller is refused.
      final anonymous = await send('ping');
      expect(anonymous['ok'], isFalse);
      expect((anonymous['error'] as Map)['code'], 'unauthorized');

      // Act & Assert — an authenticated caller is served.
      final ping = await send('ping', token: 'Bearer member-token');
      expect(ping['ok'], isTrue);
      expect((ping['result'] as Map)['app'], 'Sample');

      // Act & Assert — describe publishes the catalog.
      final describe = await send('describe', token: 'member-token');
      final catalog = (describe['result'] as Map)['commands'] as List;
      final commandIds = catalog
          .map((command) => (command as Map)['id'])
          .toList();
      expect(describe['ok'], isTrue);
      expect(commandIds, containsAll(['navigate', 'set_value', 'tap']));
      expect(commandIds, contains('archive_order'));

      // Act & Assert — state reports the route and the indexed elements.
      final state = await send('state', token: 'member-token');
      final elements = ((state['result'] as Map)['elements'] as List)
          .map((element) => (element as Map)['id'])
          .toList();
      expect((state['result'] as Map)['route'], '/');
      expect(elements, containsAll(['home_form_input_name']));

      // Act & Assert — set_value writes through the widget's own setter.
      final setValue = await invoke(
        'set_value',
        token: 'member-token',
        params: <String, dynamic>{
          'elementId': 'home_form_input_name',
          'value': 'Ada',
        },
      );
      await tester.pump();
      expect(setValue['ok'], isTrue);
      expect(find.text('name:Ada'), findsOneWidget);

      // Act & Assert — wait_for synchronizes on the new value.
      final waitFor = await invoke(
        'wait_for',
        token: 'member-token',
        params: <String, dynamic>{
          'elementId': 'home_form_input_name',
          'value': 'Ada',
        },
      );
      expect(waitFor['ok'], isTrue);
      expect((waitFor['result'] as Map)['matched'], isTrue);

      // Act & Assert — tap activates the button.
      final tap = await invoke(
        'tap',
        token: 'member-token',
        params: <String, dynamic>{'elementId': 'home_form_button_submit'},
      );
      await tester.pump();
      expect(tap['ok'], isTrue);
      expect(find.text('submits:1'), findsOneWidget);

      // Act & Assert — a command the caller's role forbids is refused.
      final forbidden = await invoke('archive_order', token: 'member-token');
      expect(forbidden['ok'], isFalse);
      expect((forbidden['error'] as Map)['code'], 'unauthorized');
      expect((forbidden['error'] as Map)['message'], contains('admin'));

      // Act & Assert — the same command succeeds for an admin.
      final archived = await invoke('archive_order', token: 'admin-token');
      expect(archived['ok'], isTrue);
      expect((archived['result'] as Map)['archived'], isTrue);

      // Act & Assert — navigate opens another route.
      final navigate = await invoke(
        'navigate',
        token: 'member-token',
        params: <String, dynamic>{'route': '/settings'},
      );
      await tester.pumpAndSettle();
      expect(navigate['ok'], isTrue);
      expect(find.text('settings'), findsOneWidget);
      final afterNavigation = await send('state', token: 'member-token');
      expect((afterNavigation['result'] as Map)['route'], '/settings');

      // Assert — every invoke was audited, attributed, and redacted.
      expect(records.map((record) => record.commandId), [
        'set_value',
        'wait_for',
        'tap',
        'archive_order',
        'archive_order',
        'navigate',
      ]);
      expect(records.first.principalId, 'user-member');
      expect(records.first.outcome, AgentAuditOutcome.success);
      expect(records.first.params, {
        'elementId': '<string:20>',
        'value': '<string:3>',
      });
      final forbiddenRecord = records[3];
      expect(forbiddenRecord.principalId, 'user-member');
      expect(forbiddenRecord.outcome, AgentAuditOutcome.failure);
      for (final record in records) {
        expect(record.toJson().toString(), isNot(contains('member-token')));
        expect(record.toJson().toString(), isNot(contains('Ada')));
      }

      await transport.stop();
    });
  });
}
