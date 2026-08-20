import '../../serialized/agent_error.dart';

/// Signals a failure that should be reported to the caller as an [AgentError].
///
/// Command handlers throw this to control the error code returned by the
/// bridge. Any other thrown object is reported as [AgentErrorCode.failed].
class AgentException implements Exception {
  /// Creates an exception carrying an explicit [code] and [message].
  AgentException(this.code, this.message);

  /// Creates an [AgentErrorCode.invalidParams] failure with [message].
  AgentException.invalidParams(this.message)
    : code = AgentErrorCode.invalidParams;

  /// Creates an [AgentErrorCode.notFound] failure with [message].
  AgentException.notFound(this.message) : code = AgentErrorCode.notFound;

  /// Creates an [AgentErrorCode.unauthorized] failure with [message].
  AgentException.unauthorized(this.message)
    : code = AgentErrorCode.unauthorized;

  /// Creates an [AgentErrorCode.failed] failure with [message].
  AgentException.failed(this.message) : code = AgentErrorCode.failed;

  /// Classifies the failure for the caller.
  final AgentErrorCode code;

  /// Explains the failure in human-readable form.
  final String message;

  /// Converts this exception into its serializable error payload.
  AgentError toError() => AgentError(code: code, message: message);

  /// Returns a debug-friendly description of the failure.
  @override
  String toString() => 'AgentException(${code.name}): $message';
}
