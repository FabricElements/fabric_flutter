import 'dart:async';

import '../../serialized/agent_command_info.dart';
import '../../serialized/agent_param.dart';
import 'agent_exception.dart';

/// Runs the work associated with an [AgentCommand].
///
/// The returned value must be JSON-serializable because it is placed directly
/// into the `result` field of the bridge response.
typedef AgentCommandHandler =
    FutureOr<Object?> Function(AgentCommandContext context);

/// Carries everything a command handler needs to run a single invocation.
///
/// The context deliberately exposes a [meta] map so a higher layer, such as the
/// authentication interceptor added on top of this core, can attach the
/// resolved principal or role claims without changing this signature.
class AgentCommandContext {
  /// Creates the context for one command invocation.
  AgentCommandContext({
    required this.commandId,
    required this.requestId,
    Map<String, dynamic>? params,
    Map<String, dynamic>? meta,
  }) : params = params ?? const {},
       meta = meta ?? <String, dynamic>{};

  /// Identifies the command being invoked.
  final String commandId;

  /// Correlates the invocation with the originating request.
  final String requestId;

  /// Holds the arguments supplied by the caller; empty when none were sent.
  final Map<String, dynamic> params;

  /// Carries values attached by upper layers, such as the resolved principal.
  final Map<String, dynamic> meta;

  /// Returns the raw parameter stored under [name], or `null` when absent.
  Object? operator [](String name) => params[name];

  /// Returns the value stored under [name] cast to [T], or `null` when absent.
  ///
  /// Throws an [AgentException] with [AgentErrorCode.invalidParams] when the
  /// value is present but is not a [T].
  T? optional<T>(String name) {
    final value = params[name];
    if (value == null) return null;
    if (value is T) return value;
    throw AgentException.invalidParams(
      'Parameter "$name" must be a ${T.toString()}.',
    );
  }

  /// Returns the value stored under [name] cast to [T].
  ///
  /// Throws an [AgentException] with [AgentErrorCode.invalidParams] when the
  /// value is missing or is not a [T].
  T require<T>(String name) {
    final value = optional<T>(name);
    if (value == null) {
      throw AgentException.invalidParams('Parameter "$name" is required.');
    }
    return value;
  }
}

/// Pairs a serializable command description with its executable handler.
///
/// The description ([info]) is what `describe` publishes; the [handler] never
/// crosses the transport boundary. Host applications create these and register
/// them in an `AgentRegistry` so agents can discover and run domain actions.
class AgentCommand {
  /// Creates a command from an existing [info] description and its [handler].
  const AgentCommand({required this.info, required this.handler});

  /// Creates a command by describing it inline.
  ///
  /// This is the convenient form for host applications: it builds the
  /// [AgentCommandInfo] from the supplied metadata so callers do not need to
  /// import the serialized model directly.
  AgentCommand.define({
    required String id,
    required String title,
    String? description,
    String category = 'general',
    List<AgentParam> params = const [],
    String? requiresRole,
    required this.handler,
  }) : info = AgentCommandInfo(
         id: id,
         title: title,
         description: description,
         category: category,
         params: params,
         requiresRole: requiresRole,
       );

  /// Describes the command in the form published by `describe`.
  final AgentCommandInfo info;

  /// Executes the command for a single invocation.
  final AgentCommandHandler handler;

  /// Returns the command identifier, shorthand for `info.id`.
  String get id => info.id;

  /// Returns the command category, shorthand for `info.category`.
  String get category => info.category;

  /// Returns the role required to invoke the command, when restricted.
  ///
  /// This core layer only carries the value through to the injected authorizer;
  /// it performs no access checks of its own.
  String? get requiresRole => info.requiresRole;

  /// Validates [params] against [AgentCommandInfo.params].
  ///
  /// Throws an [AgentException] with [AgentErrorCode.invalidParams] when a
  /// required parameter is missing or when a value falls outside a declared
  /// enumeration.
  void validate(Map<String, dynamic> params) {
    for (final param in info.params) {
      final value = params[param.name];
      if (value == null) {
        if (param.required) {
          throw AgentException.invalidParams(
            'Parameter "${param.name}" is required by command "$id".',
          );
        }
        continue;
      }
      final options = param.enumValues;
      if (options != null && !options.contains(value.toString())) {
        throw AgentException.invalidParams(
          'Parameter "${param.name}" must be one of: ${options.join(', ')}.',
        );
      }
    }
  }
}
