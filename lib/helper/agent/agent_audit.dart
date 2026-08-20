import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../serialized/agent_audit_record.dart';
import '../log_color.dart';

/// Receives one [AgentAuditRecord] per completed agent invocation.
///
/// Hosts inject a sink to forward the trail to their own logging, analytics, or
/// Firestore audit collection. A sink must not throw; a thrown error is caught
/// and reported through [debugPrint] so auditing can never break a request.
typedef AgentAuditSink = FutureOr<void> Function(AgentAuditRecord record);

/// Summarizes command parameters without exposing their values.
///
/// Audit records must be safe to persist and ship off device, so a parameter is
/// never written verbatim. Every value is replaced by a short description of
/// its type and size — `<string:11>`, `<list:3>` — and a key whose name looks
/// like a credential is replaced by `<redacted>` with no size at all, so not
/// even the length of a token leaks.
class AgentAuditRedactor {
  /// Creates a redactor, optionally replacing the sensitive key names.
  ///
  /// [sensitiveKeys] is matched case insensitively against the parameter name
  /// with `_`, `-`, and `.` removed, so `access_token`, `accessToken`, and
  /// `Access-Token` are all caught by the single entry `accesstoken`.
  const AgentAuditRedactor({this.sensitiveKeys = defaultSensitiveKeys});

  /// Lists the normalized key names whose values are fully redacted.
  final Set<String> sensitiveKeys;

  /// Names the parameters that are never summarized, only redacted.
  static const Set<String> defaultSensitiveKeys = <String>{
    'auth',
    'authorization',
    'token',
    'accesstoken',
    'refreshtoken',
    'idtoken',
    'apikey',
    'secret',
    'clientsecret',
    'password',
    'newpassword',
    'currentpassword',
    'credential',
    'credentials',
    'pin',
    'otp',
    'ssn',
    'cardnumber',
    'cvv',
  };

  /// Marks a value that was withheld entirely.
  static const String redacted = '<redacted>';

  /// Returns a redacted, value-free summary of [params].
  ///
  /// A `null` or empty map yields an empty summary. Keys are preserved because
  /// knowing *which* argument was sent is what makes an audit trail useful;
  /// only values are withheld.
  Map<String, String> redact(Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) return const <String, String>{};
    final summary = <String, String>{};
    params.forEach((key, value) {
      summary[key] = isSensitive(key) ? redacted : describe(value);
    });
    return summary;
  }

  /// Reports whether [key] names a credential that must be fully withheld.
  bool isSensitive(String key) {
    final normalized = key
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '')
        .replaceAll('.', '');
    return sensitiveKeys.contains(normalized);
  }

  /// Returns a type-and-size description of [value] that carries no content.
  ///
  /// Strings and collections publish their length because it helps diagnose an
  /// empty or truncated argument, while numbers and booleans publish only their
  /// type because a value such as an amount can itself be sensitive.
  String describe(Object? value) {
    if (value == null) return '<null>';
    if (value is String) return '<string:${value.length}>';
    if (value is bool) return '<bool>';
    if (value is num) return '<num>';
    if (value is List) return '<list:${value.length}>';
    if (value is Map) return '<map:${value.length}>';
    return '<${value.runtimeType}>';
  }
}

/// Delivers audit records to a sink without ever failing a request.
///
/// The bridge calls [record] on the hot path, so this wrapper swallows and
/// reports sink failures instead of letting them surface to the agent. When no
/// sink is configured nothing is written in release builds; in debug builds the
/// record is printed through [debugPrint] so the trail is visible during
/// development.
class AgentAuditLog {
  /// Creates an audit log that forwards to [sink].
  const AgentAuditLog({this.sink, this.debugLog = true});

  /// Receives every record, when the host supplied one.
  final AgentAuditSink? sink;

  /// Reports whether records are also printed in debug builds.
  final bool debugLog;

  /// Delivers [entry] to [sink], reporting rather than throwing on failure.
  Future<void> record(AgentAuditRecord entry) async {
    if (debugLog && kDebugMode) {
      debugPrint(
        'agent-audit ${entry.timestamp.toIso8601String()} '
        '${entry.principalId} ${entry.commandId} '
        '${entry.outcome.name} ${entry.durationMs}ms ${entry.params}',
      );
    }
    final target = sink;
    if (target == null) return;
    try {
      await target(entry);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(LogColor.error('The agent audit sink failed: $error'));
      }
    }
  }
}
