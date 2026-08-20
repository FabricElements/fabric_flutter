import 'dart:async';

import '../../serialized/agent_command_info.dart';
import '../../serialized/agent_param.dart';
import '../../serialized/agent_state_result.dart';
import '../app_global.dart';
import 'agent_command.dart';
import 'agent_element_index.dart';
import 'agent_exception.dart';
import 'agent_navigator_observer.dart';
import 'agent_registry.dart';

/// Reads the current screen state for the built-in state commands.
typedef AgentStateReader = AgentStateResult Function();

/// Builds the commands every agent bridge provides out of the box.
///
/// These commands give an agent the same reach a human user has: navigate
/// anywhere, read the current screen, set any indexed input, tap any indexed
/// button, and synchronize on a condition. Host applications register their own
/// domain commands alongside them in the same [AgentRegistry].
///
/// The class takes its collaborators explicitly rather than reaching for the
/// bridge, which keeps it free of transport and access-control concerns.
class AgentBuiltInCommands {
  /// Creates the built-in command set.
  AgentBuiltInCommands({
    required this.registry,
    required this.elements,
    required this.navigatorObserver,
    required this.stateReader,
    this.pollInterval = const Duration(milliseconds: 50),
  });

  /// Provides the catalog inspected by `list_commands`.
  final AgentRegistry registry;

  /// Provides the live element index driven by `set_value`, `tap`, and friends.
  final AgentElementIndex elements;

  /// Provides the active route consulted by `wait_for`.
  final AgentNavigatorObserver navigatorObserver;

  /// Builds the payload returned by `screen_state`.
  final AgentStateReader stateReader;

  /// Sets how often `wait_for` re-evaluates its condition.
  final Duration pollInterval;

  /// Returns every built-in command, ready to be registered.
  List<AgentCommand> build() => <AgentCommand>[
    _navigate(),
    _setValue(),
    _tap(),
    _readValue(),
    _waitFor(),
    _screenState(),
    _listCommands(),
  ];

  /// Builds the `navigate` command.
  AgentCommand _navigate() => AgentCommand.define(
    id: 'navigate',
    title: 'Navigate',
    description:
        'Opens a named route. Use the route names published by describe.',
    category: 'navigation',
    params: [
      AgentParam(
        name: 'route',
        required: true,
        description: 'Named route to open, for example /dashboard.',
      ),
      AgentParam(
        name: 'params',
        type: AgentParamType.object,
        description: 'Arguments passed to the route.',
      ),
      AgentParam(
        name: 'replace',
        type: AgentParamType.boolean,
        description:
            'Replaces the current route instead of pushing on top of it.',
      ),
    ],
    handler: (context) {
      final route = context.require<String>('route');
      final params = context.optional<Map<String, dynamic>>('params');
      final replace = context.optional<bool>('replace') ?? false;
      final navigator = AppGlobal.navigatorKey.currentState;
      if (navigator == null) {
        throw AgentException.failed(
          'No navigator is available. Assign AppGlobal.navigatorKey to '
          'MaterialApp.navigatorKey.',
        );
      }
      // The returned future completes only when the route is popped, so it is
      // deliberately not awaited here.
      if (replace) {
        unawaited(navigator.pushReplacementNamed(route, arguments: params));
      } else {
        unawaited(navigator.pushNamed(route, arguments: params));
      }
      return <String, dynamic>{'route': route, 'replaced': replace};
    },
  );

  /// Builds the `set_value` command.
  AgentCommand _setValue() => AgentCommand.define(
    id: 'set_value',
    title: 'Set value',
    description:
        'Sets the value of an indexed input exactly as user input would, '
        'including validation and listener notification.',
    category: 'interaction',
    params: [
      AgentParam(
        name: 'elementId',
        required: true,
        description: 'Identifier of the element, matching its automationKey.',
      ),
      AgentParam(
        name: 'value',
        description:
            'New value. Any JSON primitive is accepted; null clears the field.',
      ),
    ],
    handler: (context) async {
      final id = context.require<String>('elementId');
      final handle = elements.handle(id);
      if (handle == null) {
        throw AgentException.notFound('No element is indexed under "$id".');
      }
      final setter = handle.setter;
      if (setter == null) {
        throw AgentException.failed('Element "$id" does not accept a value.');
      }
      if (!handle.enabled) {
        throw AgentException.failed('Element "$id" is disabled.');
      }
      await setter(context['value']);
      return <String, dynamic>{'id': id, 'value': handle.value};
    },
  );

  /// Builds the `tap` command.
  AgentCommand _tap() => AgentCommand.define(
    id: 'tap',
    title: 'Tap',
    description: 'Activates an indexed button or tappable element.',
    category: 'interaction',
    params: [
      AgentParam(
        name: 'elementId',
        required: true,
        description: 'Identifier of the element, matching its automationKey.',
      ),
    ],
    handler: (context) async {
      final id = context.require<String>('elementId');
      final handle = elements.handle(id);
      if (handle == null) {
        throw AgentException.notFound('No element is indexed under "$id".');
      }
      final activator = handle.activator;
      if (activator == null) {
        throw AgentException.failed('Element "$id" cannot be tapped.');
      }
      if (!handle.enabled) {
        throw AgentException.failed('Element "$id" is disabled.');
      }
      await activator();
      return <String, dynamic>{'id': id, 'tapped': true};
    },
  );

  /// Builds the `read_value` command.
  AgentCommand _readValue() => AgentCommand.define(
    id: 'read_value',
    title: 'Read value',
    description: 'Reads the current state of a single indexed element.',
    category: 'inspection',
    params: [
      AgentParam(
        name: 'elementId',
        required: true,
        description: 'Identifier of the element, matching its automationKey.',
      ),
    ],
    handler: (context) {
      final id = context.require<String>('elementId');
      final snapshot = elements.snapshotOf(id);
      if (snapshot == null) {
        throw AgentException.notFound('No element is indexed under "$id".');
      }
      return snapshot.toJson();
    },
  );

  /// Builds the `wait_for` command.
  AgentCommand _waitFor() => AgentCommand.define(
    id: 'wait_for',
    title: 'Wait for',
    description:
        'Waits until an element or route reaches the requested condition, so '
        'an agent can synchronize without polling screenshots.',
    category: 'synchronization',
    params: [
      AgentParam(
        name: 'elementId',
        description: 'Element to watch. Required unless route is supplied.',
      ),
      AgentParam(
        name: 'route',
        description:
            'Route name to wait for. Required unless elementId is '
            'supplied.',
      ),
      AgentParam(
        name: 'condition',
        enumValues: const ['visible', 'absent', 'enabled', 'disabled', 'value'],
        description:
            'Condition to satisfy. Defaults to visible, or to value when an '
            'expected value is supplied.',
      ),
      AgentParam(
        name: 'value',
        description:
            'Expected value, compared as a string. Implies the value '
            'condition.',
      ),
      AgentParam(
        name: 'timeoutMs',
        type: AgentParamType.integer,
        description: 'Milliseconds to wait before failing. Defaults to 5000.',
      ),
    ],
    handler: (context) async {
      final elementId = context.optional<String>('elementId');
      final route = context.optional<String>('route');
      if (elementId == null && route == null) {
        throw AgentException.invalidParams(
          'Either "elementId" or "route" is required.',
        );
      }
      final expected = context['value'];
      final condition =
          context.optional<String>('condition') ??
          (expected != null ? 'value' : 'visible');
      final timeoutMs = context.optional<int>('timeoutMs') ?? 5000;
      final stopwatch = Stopwatch()..start();
      final timeout = Duration(milliseconds: timeoutMs);
      while (true) {
        if (_conditionMet(
          elementId: elementId,
          route: route,
          condition: condition,
          expected: expected,
        )) {
          stopwatch.stop();
          return <String, dynamic>{
            'matched': true,
            'condition': condition,
            'waitedMs': stopwatch.elapsedMilliseconds,
          };
        }
        if (stopwatch.elapsed >= timeout) {
          stopwatch.stop();
          throw AgentException.failed(
            'Timed out after ${stopwatch.elapsedMilliseconds}ms waiting for '
            'condition "$condition".',
          );
        }
        await Future<void>.delayed(pollInterval);
      }
    },
  );

  /// Builds the `screen_state` command.
  AgentCommand _screenState() => AgentCommand.define(
    id: 'screen_state',
    title: 'Screen state',
    description:
        'Returns the active route and every element currently indexed on it. '
        'Equivalent to the state method.',
    category: 'inspection',
    handler: (context) => stateReader().toJson(),
  );

  /// Builds the `list_commands` command.
  AgentCommand _listCommands() => AgentCommand.define(
    id: 'list_commands',
    title: 'List commands',
    description:
        'Lists every registered command, optionally filtered by '
        'category.',
    category: 'inspection',
    params: [
      AgentParam(
        name: 'category',
        description: 'Restricts the result to a single command category.',
      ),
    ],
    handler: (context) {
      final category = context.optional<String>('category');
      final List<AgentCommandInfo> catalog = category == null
          ? registry.catalog()
          : registry
                .withCategory(category)
                .map((command) => command.info)
                .toList(growable: false);
      return catalog.map((info) => info.toJson()).toList(growable: false);
    },
  );

  /// Reports whether the requested `wait_for` condition currently holds.
  ///
  /// Throws an [AgentException] with [AgentErrorCode.invalidParams] when the
  /// condition name is not recognized.
  bool _conditionMet({
    String? elementId,
    String? route,
    required String condition,
    Object? expected,
  }) {
    if (route != null && navigatorObserver.routeName != route) return false;
    if (elementId == null) return true;
    final handle = elements.handle(elementId);
    switch (condition) {
      case 'visible':
        return handle != null && handle.visible;
      case 'absent':
        return handle == null || !handle.visible;
      case 'enabled':
        return handle != null && handle.visible && handle.enabled;
      case 'disabled':
        return handle != null && handle.visible && !handle.enabled;
      case 'value':
        if (handle == null) return false;
        return handle.value?.toString() == expected?.toString();
      default:
        throw AgentException.invalidParams(
          'Unknown condition "$condition". Expected one of: visible, absent, '
          'enabled, disabled, value.',
        );
    }
  }
}
