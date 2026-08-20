import 'dart:async';
import 'dart:collection';

import '../../serialized/agent_principal.dart';
import '../../serialized/agent_request.dart';

/// Verifies a bearer token and resolves the caller it belongs to.
///
/// The host application owns this callback because only it knows how tokens are
/// issued — the `fabric_flutter` bridge deliberately implements no login, token
/// minting, or refresh. Returning `null` means the token is unknown, invalid,
/// expired, or revoked, and the request is denied with `unauthorized`.
///
/// Implementations must not throw for an invalid token; a thrown error is
/// treated as a denial and is never surfaced to the caller verbatim.
typedef AgentTokenVerifier = FutureOr<AgentPrincipal?> Function(String token);

/// Resolves bearer tokens to principals with a short-lived cache.
///
/// Agents issue many requests in quick succession, and verifying a token often
/// means a network round trip. The resolver caches a successful verification
/// for [cacheTtl] so a burst of calls costs a single verification, while the
/// bound on the cache lifetime keeps a revoked token from working for long.
/// Failed verifications are never cached, so a token that becomes valid works
/// on the next attempt.
class AgentPrincipalResolver {
  /// Creates a resolver around the host-supplied [verifier].
  ///
  /// [cacheTtl] bounds how long a verified principal is reused, and
  /// [maxCacheEntries] bounds memory by evicting the least recently used entry.
  AgentPrincipalResolver({
    required this.verifier,
    this.cacheTtl = const Duration(minutes: 5),
    this.maxCacheEntries = 128,
  }) : assert(maxCacheEntries > 0, 'maxCacheEntries must be greater than zero');

  /// Verifies a raw token on behalf of the host.
  final AgentTokenVerifier verifier;

  /// Bounds how long a verified principal is reused before re-verification.
  final Duration cacheTtl;

  /// Bounds how many verified principals are held in memory.
  final int maxCacheEntries;

  /// Holds verified principals keyed by their raw token.
  ///
  /// A [LinkedHashMap] preserves insertion order, which is what makes the
  /// least-recently-used eviction below possible. The map is private and its
  /// keys are never logged or serialized.
  final LinkedHashMap<String, _CachedPrincipal> _cache =
      LinkedHashMap<String, _CachedPrincipal>();

  /// Returns the principal behind [token], or `null` when it is not valid.
  ///
  /// A `null`, empty, or whitespace-only token resolves to `null` without
  /// calling [verifier]. An expired principal — either past its cache lifetime
  /// or past [AgentPrincipal.expiresAt] — is discarded and re-verified.
  Future<AgentPrincipal?> resolve(String? token) async {
    final normalized = normalizeToken(token);
    if (normalized == null) return null;
    final cached = _cache.remove(normalized);
    if (cached != null && !cached.isStale(cacheTtl)) {
      _cache[normalized] = cached;
      return cached.principal;
    }
    AgentPrincipal? principal;
    try {
      principal = await verifier(normalized);
    } catch (_) {
      // A verifier failure is a denial; the reason is never leaked to the
      // caller because it may describe internal infrastructure.
      return null;
    }
    if (principal == null || principal.isExpired) return null;
    _cache[normalized] = _CachedPrincipal(
      principal: principal,
      verifiedAt: DateTime.now(),
    );
    while (_cache.length > maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    return principal;
  }

  /// Drops [token] from the cache, or the whole cache when [token] is `null`.
  ///
  /// Hosts call this on sign-out or token revocation so the next request is
  /// verified again immediately.
  void invalidate([String? token]) {
    final normalized = normalizeToken(token);
    if (normalized == null) {
      _cache.clear();
      return;
    }
    _cache.remove(normalized);
  }

  /// Strips an optional `Bearer ` prefix and surrounding whitespace from [token].
  ///
  /// Returns `null` when nothing usable remains, which lets every caller treat
  /// a missing and an empty token identically. The comparison is case
  /// insensitive because RFC 6750 declares the scheme name case insensitive.
  static String? normalizeToken(String? token) {
    if (token == null) return null;
    var value = token.trim();
    if (value.toLowerCase() == 'bearer') return null;
    value = value.replaceFirst(_bearerPrefix, '').trim();
    return value.isEmpty ? null : value;
  }

  /// Matches a leading `Bearer` scheme name and the whitespace after it.
  static final RegExp _bearerPrefix = RegExp(
    r'^bearer\s+',
    caseSensitive: false,
  );

  /// Extracts the bearer token carried by [request].
  ///
  /// The token travels in the reserved `auth` field of the request parameters —
  /// `{"id": "1", "method": "invoke", "params": {"auth": "Bearer <token>"}}` —
  /// which keeps it out of the command arguments in `params.params` and works
  /// on every transport, including ones without headers. A transport that
  /// carries its own credential, such as an `Authorization` header on a
  /// WebSocket handshake, injects it into this field before dispatching.
  /// Returns `null` when the field is absent or is not a non-empty string.
  static String? tokenFromRequest(AgentRequest request) =>
      tokenFromParams(request.params);

  /// Extracts the bearer token from a raw request [params] map.
  ///
  /// Behaves exactly like [tokenFromRequest] but works before the envelope has
  /// been deserialized, which is what a transport needs.
  static String? tokenFromParams(Map<String, dynamic>? params) {
    final value = params?[authField];
    return value is String ? normalizeToken(value) : null;
  }

  /// Names the reserved request parameter that carries the bearer token.
  static const String authField = 'auth';
}

/// Holds one verified principal together with the time it was verified.
class _CachedPrincipal {
  /// Creates a cache entry for [principal] verified at [verifiedAt].
  const _CachedPrincipal({required this.principal, required this.verifiedAt});

  /// Stores the principal returned by the verifier.
  final AgentPrincipal principal;

  /// Marks when the verification happened.
  final DateTime verifiedAt;

  /// Reports whether the entry may no longer be reused after [ttl].
  bool isStale(Duration ttl) =>
      principal.isExpired || DateTime.now().difference(verifiedAt) >= ttl;
}
