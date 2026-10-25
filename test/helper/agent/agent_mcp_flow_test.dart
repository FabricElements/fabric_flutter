import 'dart:async';

import 'package:fabric_flutter/component/input_data.dart';
import 'package:fabric_flutter/component/smart_button.dart';
import 'package:fabric_flutter/helper/agent/agent_authorizer.dart';
import 'package:fabric_flutter/helper/agent/agent_bridge.dart';
import 'package:fabric_flutter/helper/agent/agent_bridge_server_options.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/helper/agent/agent_navigator_observer.dart';
import 'package:fabric_flutter/helper/agent/agent_transport.dart';
import 'package:fabric_flutter/helper/app_global.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:fabric_flutter/serialized/agent_audit_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an enabled bridge backed by an isolated element index.
AgentBridge _bridge({
  AgentElementIndex? index,
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
    authorizer: const AgentAllowAllAuthorizer(),
  );
  return bridge;
}

/// Builds an in-process transport and collects audit records into [records].
AgentInProcessTransport _transport(
  List<AgentAuditRecord> records, {
  required AgentBridge bridge,
}) => AgentInProcessTransport(
  dispatcher: AgentTransport.createDispatcher(
    bridge: bridge,
    options: const AgentBridgeServerOptions(requireAuth: false),
    transportName: 'test',
    auditSink: records.add,
  ),
);

/// Builds an MCP JSON-RPC request map.
Map<String, dynamic> _rpc(
  String method, {
  Map<String, dynamic>? params,
  String id = '1',
}) {
  final map = <String, dynamic>{'jsonrpc': '2.0', 'id': id, 'method': method};
  if (params != null) {
    map['params'] = params;
  }
  return map;
}

/// A screen built from existing fabric_flutter components: a long [ListView]
/// whose bottom contains a [Form] with [InputData] fields and a [SmartButton].
class _FlowScreen extends StatefulWidget {
  const _FlowScreen({required this.observer, this.onSubmit});

  final AgentNavigatorObserver observer;
  final VoidCallback? onSubmit;

  @override
  State<_FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<_FlowScreen> {
  String _name = '';
  String? _color = 'Red';

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: AppGlobal.navigatorKey,
    navigatorObservers: [widget.observer],
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            for (var i = 0; i < 40; i++)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Filler row $i'),
              ),
            Form(
              child: Column(
                children: [
                  InputData(
                    type: InputDataType.text,
                    value: _name,
                    label: 'Name',
                    automationKey: 'flow_text_name',
                    required: true,
                    onChanged: (v) =>
                        setState(() => _name = v?.toString() ?? ''),
                  ),
                  InputData(
                    type: InputDataType.dropdown,
                    value: _color,
                    label: 'Color',
                    automationKey: 'flow_dropdown_color',
                    options: [
                      ButtonOptions(value: 'Red', label: 'Red'),
                      ButtonOptions(value: 'Green', label: 'Green'),
                      ButtonOptions(value: 'Blue', label: 'Blue'),
                    ],
                    onChanged: (v) => setState(() => _color = v as String?),
                  ),
                  SmartButton(
                    automationKey: 'flow_button_submit',
                    button: ButtonOptions(
                      label: 'Submit',
                      onTap: widget.onSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Agent MCP flow over fabric components', () {
    testWidgets('should drive a screen through MCP JSON-RPC frames', (
      tester,
    ) async {
      // ---- arrange ----

      final index = AgentElementIndex.instance;
      index.reset();
      final observer = AgentNavigatorObserver();
      final bridge = _bridge(index: index, observer: observer);
      final records = <AgentAuditRecord>[];
      final transport = _transport(records, bridge: bridge);

      // ---- helpers ----

      /// Starts [future] and pumps 50 ms up to 100 times until it resolves.
      Future<T> pumpUntilDone<T>(Future<T> future) async {
        final completer = Completer<T>();
        future.then((v) {
          if (!completer.isCompleted) completer.complete(v);
        });
        for (var i = 0; i < 100 && !completer.isCompleted; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (!completer.isCompleted) {
          throw StateError('Future did not complete after 100 pumps');
        }
        return completer.future;
      }

      /// Sends an MCP [method] with [params] and pumps until the response
      /// arrives.
      Future<Map<String, dynamic>?> call(
        String method, {
        Map<String, dynamic>? params,
        String id = '1',
      }) => pumpUntilDone(transport.send(_rpc(method, params: params, id: id)));

      final submitted = Completer<void>();
      final semanticsHandle = tester.ensureSemantics();
      await tester.pumpWidget(
        _FlowScreen(
          observer: observer,
          onSubmit: () {
            if (!submitted.isCompleted) submitted.complete();
          },
        ),
      );
      await tester.pumpAndSettle();

      // Each element is findable by its automationKey.
      expect(find.bySemanticsIdentifier('flow_text_name'), findsOneWidget);
      expect(find.bySemanticsIdentifier('flow_dropdown_color'), findsOneWidget);
      expect(find.bySemanticsIdentifier('flow_button_submit'), findsOneWidget);

      // ---- tools/list ----

      final toolsList = await call('tools/list');
      final tools = (toolsList!['result'] as Map)['tools'] as List;
      final toolNames = tools.map((t) => (t as Map)['name']).toList();
      expect(
        toolNames,
        containsAll([
          'element__reveal',
          'element__focus',
          'set_value',
          'form__submit',
          'tap',
        ]),
      );

      // ---- element__reveal ----

      final reveal = await call(
        'tools/call',
        params: <String, dynamic>{
          'name': 'element__reveal',
          'arguments': <String, dynamic>{'elementId': 'flow_text_name'},
        },
        id: '2',
      );
      final revealResult =
          (reveal!['result'] as Map)['structuredContent'] as Map;
      expect(revealResult['id'], 'flow_text_name');
      expect(revealResult['revealed'], isTrue);

      // ---- element__focus ----

      final focus = await call(
        'tools/call',
        params: <String, dynamic>{
          'name': 'element__focus',
          'arguments': <String, dynamic>{'elementId': 'flow_text_name'},
        },
        id: '3',
      );
      final focusResult = (focus!['result'] as Map)['structuredContent'] as Map;
      expect(focusResult['id'], 'flow_text_name');
      expect(focusResult['focused'], isTrue);

      // ---- form__submit (empty → invalid) ----

      final submitEmpty = await call(
        'tools/call',
        params: <String, dynamic>{
          'name': 'form__submit',
          'arguments': <String, dynamic>{'elementId': 'flow_text_name'},
        },
        id: '4',
      );
      final submitEmptyResult =
          (submitEmpty!['result'] as Map)['structuredContent'] as Map;
      expect(submitEmptyResult['valid'], isFalse);
      expect(
        (submitEmptyResult['errors'] as Map).containsKey('flow_text_name'),
        isTrue,
      );

      // ---- set_value with a valid string ----

      final setString = await call(
        'tools/call',
        params: <String, dynamic>{
          'name': 'set_value',
          'arguments': <String, dynamic>{
            'elementId': 'flow_text_name',
            'value': 'Ada',
          },
        },
        id: '5',
      );
      final setStringResult =
          (setString!['result'] as Map)['structuredContent'] as Map;
      expect(setStringResult['valid'], isTrue);

      // ---- set_value with a boolean (accepted — no type in schema) ----

      final setBool = await call(
        'tools/call',
        params: <String, dynamic>{
          'name': 'set_value',
          'arguments': <String, dynamic>{
            'elementId': 'flow_text_name',
            'value': true,
          },
        },
        id: '6',
      );
      final setBoolResult =
          (setBool!['result'] as Map)['structuredContent'] as Map;
      expect(setBoolResult['valid'], isTrue);

      // ---- set_value with a number (accepted — no type in schema) ----

      final setNum = await call(
        'tools/call',
        params: <String, dynamic>{
          'name': 'set_value',
          'arguments': <String, dynamic>{
            'elementId': 'flow_text_name',
            'value': 42,
          },
        },
        id: '7',
      );
      final setNumResult =
          (setNum!['result'] as Map)['structuredContent'] as Map;
      expect(setNumResult['valid'], isTrue);

      // ---- read_value on dropdown to discover the clear action label ----

      final readDropdown = await call(
        'tools/call',
        params: <String, dynamic>{
          'name': 'read_value',
          'arguments': <String, dynamic>{'elementId': 'flow_dropdown_color'},
        },
        id: '8',
      );
      final readDropdownResult =
          (readDropdown!['result'] as Map)['structuredContent'] as Map;
      final actions = readDropdownResult['actions'] as List?;
      expect(actions, isNotNull);
      expect(actions, isNotEmpty);
      final clearLabel = actions!.first as String;

      // ---- tap with the clear action ----

      final tapClear = await call(
        'tools/call',
        params: <String, dynamic>{
          'name': 'tap',
          'arguments': <String, dynamic>{
            'elementId': 'flow_dropdown_color',
            'action': clearLabel,
          },
        },
        id: '9',
      );
      final tapClearResult =
          (tapClear!['result'] as Map)['structuredContent'] as Map;
      expect(tapClearResult['activated'], isTrue);

      // ---- read_value → value is null after clear ----

      final readAfterClear = await call(
        'tools/call',
        params: <String, dynamic>{
          'name': 'read_value',
          'arguments': <String, dynamic>{'elementId': 'flow_dropdown_color'},
        },
        id: '10',
      );
      final readAfterClearResult =
          (readAfterClear!['result'] as Map)['structuredContent'] as Map;
      expect(readAfterClearResult['value'], isNull);

      // ---- form__submit (valid after set_value) ----

      final submitValid = await call(
        'tools/call',
        params: <String, dynamic>{
          'name': 'form__submit',
          'arguments': <String, dynamic>{'elementId': 'flow_text_name'},
        },
        id: '11',
      );
      final submitValidResult =
          (submitValid!['result'] as Map)['structuredContent'] as Map;
      expect(submitValidResult['valid'], isTrue);

      // ---- tap the submit button ----

      final tapSubmit = await call(
        'tools/call',
        params: <String, dynamic>{
          'name': 'tap',
          'arguments': <String, dynamic>{'elementId': 'flow_button_submit'},
        },
        id: '12',
      );
      final tapSubmitResult =
          (tapSubmit!['result'] as Map)['structuredContent'] as Map;
      expect(tapSubmitResult['activated'], isTrue);
      // The callback ran — verify through the widget's own state.
      await tester.pump();
      expect(submitted.isCompleted, isTrue);

      // ---- unknown tool → -32602 ----

      final unknown = await call(
        'tools/call',
        params: <String, dynamic>{
          'name': 'nope',
          'arguments': <String, dynamic>{},
        },
        id: '13',
      );
      expect(unknown!['error'], isNotNull);
      expect((unknown['error'] as Map)['code'], -32602);

      // ---- notification frame → null ----

      final notification = await transport.send(<String, dynamic>{
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      });
      expect(notification, isNull);

      await transport.stop();
      semanticsHandle.dispose();
    });
  });
}
