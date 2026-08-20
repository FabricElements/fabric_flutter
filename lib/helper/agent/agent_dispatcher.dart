import 'dart:async';
import 'dart:convert';

import '../../serialized/agent_audit_record.dart';
import '../../serialized/agent_error.dart';
import '../../serialized/agent_response.dart';
import 'agent_audit.dart';
import 'agent_bridge.dart';
import 'agent_principal_resolver.dart';
import 'agent_rate_limiter.dart';

/// Applies transport-level safety controls around [AgentBridge.handle].
///
/// Every transport funnels through this dispatcher so the controls are written
/// once and cannot be forgotten by a new transport. In order, a request is
/// rejected when it is larger than [maxRequestBytes], when it is not valid
/// JSON, or when the caller has exhausted its rate limit; otherwise it reaches
/// the bridge, and an `invoke` is recorded in the audit log with its outcome
/// and duration.
///
/// The dispatcher never throws and never returns a malformed frame: every
/// failure becomes a well-formed error response carrying one of the codes in
/// [AgentErrorCode].
class AgentDispatcher {
  /// Creates a dispatcher in front of [bridge].
  ///
  /// [principals] is optional and is only used to attribute audit records and
  /// rate-limit buckets to a caller; access control itself lives in the
  /// authorizer configured on the bridge. Pass the same resolver instance used
  /// by the authorizer so a token is verified once and served from its cache.
  AgentDispatcher({
    AgentBridge? bridge,
    this.principals,
    AgentRateLimiter? rateLimiter,
    AgentAuditLog? audit,
    this.redactor = const AgentAuditRedactor(),
    this.maxRequestBytes = defaultMaxRequestBytes,
    this.transportName = 'in_process',
  }) : bridge = bridge ?? AgentBridge.instance,
       rateLimiter = rateLimiter ?? AgentRateLimiter(),
       audit = audit ?? const AgentAuditLog();

  /// Dispatches authorized requests against the running application.
  final AgentBridge bridge;

  /// Resolves the caller so audit records and rate limits can be attributed.
  final AgentPrincipalResolver? principals;

  /// Bounds how many requests one caller may issue.
  final AgentRateLimiter rateLimiter;

  /// Receives one record per completed `invoke`.
  final AgentAuditLog audit;

  /// Strips values out of audited parameters.
  final AgentAuditRedactor redactor;

  /// Bounds the size in bytes of a single encoded request.
  final int maxRequestBytes;

  /// Names the transport in audit records, such as `websocket` or `web`.
  final String transportName;

  /// Sets the default maximum encoded request size, 64 KiB.
  static const int defaultMaxRequestBytes = 64 * 1024;

  /// Identifies a caller that presented no verifiable token.
  static const String anonymousPrincipal = 'anonymous';

  /// Decodes [payload], dispatches it, and returns the encoded response.
  ///
  /// A payload larger than [maxRequestBytes] or one that is not a JSON object
  /// produces an [AgentErrorCode.invalidParams] response rather than an
  /// exception, so a transport can forward the result blindly. [connectionId]
  /// buckets the rate limit for unauthenticated callers, and [token] carries a
  /// transport-level credential such as an `Authorization` header.
  Future<String> handleJson(
    String payload, {
    String? connectionId,
    String? token,
  }) async {
    final bytes = utf8.encode(payload).length;
    if (bytes > maxRequestBytes) {
      return jsonEncode(
        _error(
          '',
          AgentErrorCode.invalidParams,
          'The request is $bytes bytes, which exceeds the '
              '$maxRequestBytes byte limit.',
        ),
      );
    }
    Map<String, dynamic>? request;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return jsonEncode(
          _error(
            '',
            AgentErrorCode.invalidParams,
            'The request must be a JSON object.',
          ),
        );
      }
      request = Map<String, dynamic>.from(decoded);
    } on FormatException catch (error) {
      return jsonEncode(
        _error(
          '',
          AgentErrorCode.invalidParams,
          'The request is not valid JSON: ${error.message}',
        ),
      );
    }
    final response = await handle(
      request,
      connectionId: connectionId,
      token: token,
    );
    return jsonEncode(response);
  }

  /// Dispatches a decoded [request] map and returns a decoded response map.
  ///
  /// When [token] is supplied and the envelope carries no `auth` parameter, the
  /// transport credential is injected so the authorizer sees a single, uniform
  /// token location regardless of transport.
  Future<Map<String, dynamic>> handle(
    Map<String, dynamic>? request, {
    String? connectionId,
    String? token,
  }) async {
    final envelope = _withTransportToken(request, token);
    final requestId = envelope[_idField] is String
        ? envelope[_idField] as String
        : '';
    final method = envelope[_methodField] is String
        ? envelope[_methodField] as String
        : '';
    final params = envelope[_paramsField] is Map
        ? Map<String, dynamic>.from(envelope[_paramsField] as Map)
        : const <String, dynamic>{};
    final principalId = await _principalId(params);
    final rateKey = principalId == anonymousPrincipal
        ? 'connection:${connectionId ?? anonymousPrincipal}'
        : 'principal:$principalId';
    if (!rateLimiter.allow(rateKey)) {
      return _error(
        requestId,
        AgentErrorCode.failed,
        'The rate limit of ${rateLimiter.maxRequests} requests per '
        '${rateLimiter.window.inSeconds}s was exceeded. Retry later.',
      );
    }
    final startedAt = DateTime.now();
    final response = await bridge.handle(envelope);
    if (method != AgentBridge.methodInvoke) return response;
    await _audit(
      requestId: requestId,
      principalId: principalId,
      params: params,
      response: response,
      duration: DateTime.now().difference(startedAt),
    );
    return response;
  }

  /// Returns [request] with [token] injected as the reserved `auth` parameter.
  ///
  /// An `auth` value already present in the envelope always wins, so a caller
  /// can address a specific principal over a shared connection. The original
  /// map is never mutated.
  Map<String, dynamic> _withTransportToken(
    Map<String, dynamic>? request,
    String? token,
  ) {
    final envelope = Map<String, dynamic>.from(request ?? <String, dynamic>{});
    final normalized = AgentPrincipalResolver.normalizeToken(token);
    if (normalized == null) return envelope;
    final params = envelope[_paramsField] is Map
        ? Map<String, dynamic>.from(envelope[_paramsField] as Map)
        : <String, dynamic>{};
    if (AgentPrincipalResolver.tokenFromParams(params) == null) {
      params[AgentPrincipalResolver.authField] = normalized;
    }
    envelope[_paramsField] = params;
    return envelope;
  }

  /// Resolves the caller identifier used for auditing and rate limiting.
  ///
  /// Falls back to [anonymousPrincipal] when no resolver is configured or the
  /// token cannot be verified; the authorizer, not this method, decides whether
  /// an anonymous caller is allowed to proceed.
  Future<String> _principalId(Map<String, dynamic> params) async {
    final resolver = principals;
    if (resolver == null) return anonymousPrincipal;
    final token = AgentPrincipalResolver.tokenFromParams(params);
    if (token == null) return anonymousPrincipal;
    final principal = await resolver.resolve(token);
    if (principal == null || principal.id.isEmpty) return anonymousPrincipal;
    return principal.id;
  }

  /// Writes one audit record describing a completed `invoke`.
  Future<void> _audit({
    required String requestId,
    required String principalId,
    required Map<String, dynamic> params,
    required Map<String, dynamic> response,
    required Duration duration,
  }) async {
    final commandId = params['commandId'];
    final rawParams = params['params'];
    final ok = response['ok'] == true;
    final error = response['error'];
    final code = error is Map ? error['code'] : null;
    await audit.record(
      AgentAuditRecord(
        timestamp: DateTime.now().toUtc(),
        requestId: requestId,
        principalId: principalId,
        commandId: commandId is String ? commandId : '',
        outcome: ok ? AgentAuditOutcome.success : AgentAuditOutcome.failure,
        durationMs: duration.inMilliseconds,
        params: redactor.redact(
          rawParams is Map ? Map<String, dynamic>.from(rawParams) : null,
        ),
        errorCode: ok ? null : _errorCode(code),
        transport: transportName,
      ),
    );
  }

  /// Maps the serialized error [code] back to its [AgentErrorCode] value.
  ///
  /// Returns [AgentErrorCode.failed] for an unknown or missing code so an audit
  /// record always classifies a failure.
  AgentErrorCode _errorCode(Object? code) {
    for (final value in AgentErrorCode.values) {
      if (_wireName(value) == code) return value;
    }
    return AgentErrorCode.failed;
  }

  /// Returns the JSON token used on the wire for [code].
  String _wireName(AgentErrorCode code) => switch (code) {
    AgentErrorCode.unauthorized => 'unauthorized',
    AgentErrorCode.notFound => 'not_found',
    AgentErrorCode.invalidParams => 'invalid_params',
    AgentErrorCode.disabled => 'disabled',
    AgentErrorCode.failed => 'failed',
  };

  /// Builds an encoded error response for [id].
  Map<String, dynamic> _error(String id, AgentErrorCode code, String message) =>
      AgentResponse.failure(
        id: id,
        error: AgentError(code: code, message: message),
      ).toJson();

  /// Names the envelope field carrying the request identifier.
  static const String _idField = 'id';

  /// Names the envelope field carrying the method name.
  static const String _methodField = 'method';

  /// Names the envelope field carrying the method parameters.
  static const String _paramsField = 'params';
}
