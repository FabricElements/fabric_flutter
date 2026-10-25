import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../serialized/agent_command_info.dart';
import '../../serialized/agent_param.dart';
import '../../serialized/agent_state_result.dart';
import '../app_global.dart';
import 'agent_command.dart';
import 'agent_element.dart';
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
    _elementReveal(),
    _elementFocus(),
    _formSubmit(),
  ];

  /// Throws an [AgentException.notFound] when the element at [id] is absent.
  ///
  /// This is used by every interaction command so "not found" is reported
  /// consistently and the guard is not repeated.
  AgentElementHandle _requireElement(String id) {
    final handle = elements.handle(id);
    if (handle == null) {
      throw AgentException.notFound('No element is indexed under "$id".');
    }
    return handle;
  }

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
        'including validation and listener notification. After the value '
        'is applied the element\'s own validator is run (when available) '
        'and the result reports whether the new value passes validation.',
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
      final handle = _requireElement(id);
      final setter = handle.setter;
      if (setter == null) {
        throw AgentException.failed('Element "$id" does not accept a value.');
      }
      if (!handle.enabled) {
        throw AgentException.failed('Element "$id" is disabled.');
      }
      await handle.reveal();
      handle.requestFocus();
      final rawValue = context['value'];
      await setter(rawValue);
      // Run the element's own validator on the new value (F7a).
      final validator = handle.validatorFn;
      final error = validator?.call(rawValue);
      return <String, dynamic>{
        'id': id,
        'value': handle.value,
        'valid': error == null,
        'error': error,
      };
    },
  );

  /// Builds the `tap` command.
  AgentCommand _tap() => AgentCommand.define(
    id: 'tap',
    title: 'Tap',
    description:
        'Activates an indexed button or tappable element. Tries '
        'ActivateIntent (Actions API) first so the standard enablement '
        'and keyboard paths run; falls back to the element\'s own '
        'activator when no ActivateIntent handler is registered.',
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
      final handle = _requireElement(id);
      if (!handle.enabled) {
        throw AgentException.failed('Element "$id" is disabled.');
      }
      // Capture context before the async gap so it can be guarded with
      // .mounted after reveal completes.
      final elementContext = handle.contextGetter?.call();
      await handle.reveal();
      // Try ActivateIntent through the Actions system first. This respects
      // isEnabled checks configured by the widget tree and is the path
      // keyboard activation follows (Enter / Space → ActivateIntent).
      if (elementContext != null && elementContext.mounted) {
        final action = Actions.maybeFind<ActivateIntent>(
          elementContext,
          intent: const ActivateIntent(),
        );
        if (action != null) {
          if (!action.isEnabled(const ActivateIntent())) {
            throw AgentException.failed(
              'Element "$id" is disabled (ActivateIntent handler is not '
              'enabled).',
            );
          }
          final result = Actions.maybeInvoke(
            elementContext,
            const ActivateIntent(),
          );
          if (result is Future) await result;
          return <String, dynamic>{
            'id': id,
            'method': 'actions',
            'activated': true,
          };
        }
      }
      // Fall back to the element's own activator callback (legacy path).
      final activator = handle.activator;
      if (activator == null) {
        throw AgentException.failed('Element "$id" cannot be tapped.');
      }
      await activator();
      return <String, dynamic>{
        'id': id,
        'method': 'activator',
        'activated': true,
      };
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

  /// Builds the `element.reveal` command.
  AgentCommand _elementReveal() => AgentCommand.define(
    id: 'element.reveal',
    title: 'Reveal element',
    description:
        'Scrolls the indexed element into view, staying with it through '
        'layout settles.',
    category: 'interaction',
    params: [
      AgentParam(
        name: 'elementId',
        required: true,
        description: 'Identifier of the element, matching its automationKey.',
      ),
      AgentParam(
        name: 'alignment',
        type: AgentParamType.number,
        description:
            'Where the element lands in the viewport: 0 at the leading edge, '
            '1 at the trailing edge. Defaults to 0.1.',
      ),
    ],
    handler: (context) async {
      final id = context.require<String>('elementId');
      final handle = _requireElement(id);
      final alignment = context.optional<num>('alignment')?.toDouble() ?? 0.1;
      final revealed = await handle.reveal(alignment: alignment);
      return <String, dynamic>{'id': id, 'revealed': revealed};
    },
  );

  /// Builds the `element.focus` command.
  AgentCommand _elementFocus() => AgentCommand.define(
    id: 'element.focus',
    title: 'Focus element',
    description:
        'Moves input focus to the element, or its first focusable descendant.',
    category: 'interaction',
    params: [
      AgentParam(
        name: 'elementId',
        required: true,
        description: 'Identifier of the element, matching its automationKey.',
      ),
    ],
    handler: (context) {
      final id = context.require<String>('elementId');
      final handle = _requireElement(id);
      final focused = handle.requestFocus();
      return <String, dynamic>{'id': id, 'focused': focused};
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

  /// Builds the `form.submit` command.
  ///
  /// Validates the enclosing [Form] for the indexed element without actually
  /// submitting it. When the form is invalid every per-field error is returned
  /// keyed by the element's `automationKey`; when the form is valid the result
  /// reports `{valid: true}` with no errors.
  AgentCommand _formSubmit() => AgentCommand.define(
    id: 'form.submit',
    title: 'Form submit (validate)',
    description:
        'Validates the Form that contains the indexed element. Does NOT '
        'submit; returns per-field errors when invalid.',
    category: 'interaction',
    params: [
      AgentParam(
        name: 'elementId',
        required: true,
        description:
            'Identifier of any element inside the target Form, matching '
            'its automationKey.',
      ),
    ],
    handler: (context) {
      final id = context.require<String>('elementId');
      final handle = _requireElement(id);
      final elementContext = handle.contextGetter?.call();
      if (elementContext == null) {
        throw AgentException.failed('Element "$id" has no widget context.');
      }
      final form = Form.maybeOf(elementContext);
      if (form == null) {
        throw AgentException.failed(
          'Element "$id" is not inside a Form widget.',
        );
      }
      final valid = form.validate();
      // After validation each FormField has updated its errorText in state.
      // Collect errors from every indexed element that carries a non-null error.
      final Map<String, String?> errors = <String, String?>{};
      for (final snapshot in elements.snapshot()) {
        final error = snapshot.error;
        if (error != null) {
          errors[snapshot.id] = error;
        }
      }
      return <String, dynamic>{
        'valid': valid,
        if (errors.isNotEmpty) 'errors': errors,
      };
    },
  );
}
