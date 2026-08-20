import 'dart:async';

import '../../serialized/agent_error.dart';
import '../../serialized/agent_request.dart';
import 'agent_command.dart';

/// Reports whether an agent request may proceed.
///
/// A denial carries the [AgentErrorCode] and message the bridge returns to the
/// caller verbatim.
class AgentAuthorization {
  /// Creates an authorization decision.
  const AgentAuthorization({
    required this.allowed,
    this.code = AgentErrorCode.unauthorized,
    this.message = '',
    this.meta = const {},
  });

  /// Creates an approving decision, optionally attaching [meta].
  ///
  /// Values placed in [meta] are forwarded to the command handler through
  /// [AgentCommandContext.meta], which is how an authentication layer passes
  /// the resolved principal or role claims down without changing signatures.
  const AgentAuthorization.allow({this.meta = const {}})
    : allowed = true,
      code = AgentErrorCode.unauthorized,
      message = '';

  /// Creates a denying decision described by [message].
  const AgentAuthorization.deny(
    this.message, {
    this.code = AgentErrorCode.unauthorized,
  }) : allowed = false,
       meta = const {};

  /// Reports whether the request may proceed.
  final bool allowed;

  /// Classifies the denial; ignored when [allowed] is `true`.
  final AgentErrorCode code;

  /// Explains the denial; ignored when [allowed] is `true`.
  final String message;

  /// Carries values forwarded to the command handler on approval.
  final Map<String, dynamic> meta;
}

/// Decides whether an agent request is allowed to run.
///
/// This is the seam where authentication and per-command role checks are
/// layered on top of the core bridge. The core itself performs no access
/// control: it simply passes the decoded [AgentRequest] and the resolved
/// [AgentCommand] — including its [AgentCommand.requiresRole] — to the
/// configured authorizer and honors the answer.
abstract class AgentAuthorizer {
  /// Creates an authorizer.
  const AgentAuthorizer();

  /// Returns the decision for [request], optionally scoped to [command].
  ///
  /// [command] is `null` for methods that do not resolve to a registered
  /// command, such as `ping` and `describe`, which lets an implementation gate
  /// discovery separately from execution.
  FutureOr<AgentAuthorization> authorize(
    AgentRequest request, {
    AgentCommand? command,
  });
}

/// Allows every request through unchanged.
///
/// This is the default authorizer, which keeps the core layer free of access
/// control. Hosts that expose the bridge beyond a trusted process must replace
/// it with a real implementation.
class AgentAllowAllAuthorizer extends AgentAuthorizer {
  /// Creates an authorizer that approves every request.
  const AgentAllowAllAuthorizer();

  /// Approves [request] unconditionally.
  @override
  FutureOr<AgentAuthorization> authorize(
    AgentRequest request, {
    AgentCommand? command,
  }) => const AgentAuthorization.allow();
}
