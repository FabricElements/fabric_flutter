import 'package:json_annotation/json_annotation.dart';

part 'agent_principal.g.dart';

/// Identifies the authenticated caller behind an agent bridge request.
///
/// A principal is produced by the host application when it verifies a bearer
/// token, so the bridge never learns how tokens are minted or refreshed. The
/// fields mirror the claims carried by the OAuth 2.0 access tokens issued to
/// agent clients: a stable subject identifier, a global `role`, and the
/// per-group roles stored under `groups`.
@JsonSerializable(explicitToJson: true)
class AgentPrincipal {
  /// Creates a principal resolved from a verified access token.
  AgentPrincipal({
    required this.id,
    this.role = 'user',
    this.groups = const {},
    this.scopes = const [],
    this.expiresAt,
    this.claims,
  });

  /// Builds an [AgentPrincipal] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty map so a malformed verifier
  /// response yields an empty principal rather than throwing.
  factory AgentPrincipal.fromJson(Map<String, dynamic>? json) =>
      _$AgentPrincipalFromJson(json ?? {});

  /// Identifies the caller, typically the user identifier or `sub` claim.
  ///
  /// This is the only principal field written to the audit log, so it must not
  /// carry personally identifying information beyond an opaque identifier.
  @JsonKey(defaultValue: '')
  final String id;

  /// Names the caller's global role, such as `admin` or `user`.
  @JsonKey(defaultValue: 'user')
  final String role;

  /// Maps a group identifier to the role the caller holds inside that group.
  ///
  /// This mirrors the `groups` claim and the shape consumed by
  /// `UserRoles.roleFromData`, where a group-scoped role is written as
  /// `<group>-<role>`.
  final Map<String, String> groups;

  /// Lists the OAuth scopes granted to the token, when the host supplies them.
  final List<String> scopes;

  /// Reports when the underlying token expires, when the host supplies it.
  ///
  /// A principal whose expiry is in the past is rejected by the gate even if it
  /// is still cached, which bounds how long a revoked token keeps working.
  final DateTime? expiresAt;

  /// Carries any additional claims the host wants forwarded to handlers.
  ///
  /// These are never written to the audit log because they may hold personal
  /// data.
  final Map<String, dynamic>? claims;

  /// Reports whether the token backing this principal has already expired.
  ///
  /// Returns `false` when [expiresAt] is `null`, because a host that does not
  /// publish an expiry is assumed to validate freshness itself. The comparison
  /// is absolute, so a UTC and a local expiry behave identically.
  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }

  /// Returns the role held in [group], or `null` when the caller has none.
  String? roleInGroup(String group) => groups[group];

  /// Converts this principal into JSON.
  Map<String, dynamic> toJson() => _$AgentPrincipalToJson(this);
}
