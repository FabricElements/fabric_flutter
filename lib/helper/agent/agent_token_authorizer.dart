import 'dart:async';

import '../../serialized/agent_error.dart';
import '../../serialized/agent_principal.dart';
import '../../serialized/agent_request.dart';
import 'agent_authorizer.dart';
import 'agent_command.dart';
import 'agent_principal_resolver.dart';

/// Decides whether [principal] satisfies [requiredRole].
///
/// A host supplies this to replace the package default when its role model
/// differs, for example when roles are hierarchical or namespaced.
typedef AgentRoleCheck =
    bool Function(AgentPrincipal principal, String requiredRole);

/// Authenticates agent requests with a bearer token and enforces command roles.
///
/// This is the access-control layer the core [AgentAuthorizer] seam was built
/// for. It performs **no** login, token minting, or refresh: an agent obtains a
/// normal OAuth 2.0 access token through the host's existing authorization-code
/// flow and presents it on every request. The authorizer only verifies that
/// token — through the host-supplied [AgentTokenVerifier] wrapped by
/// [principals] — and checks the resolved principal against
/// [AgentCommand.requiresRole].
///
/// The token travels in the reserved `auth` request parameter; see
/// [AgentPrincipalResolver.tokenFromRequest] for the exact envelope position.
///
/// On approval the resolved principal is forwarded to the command handler
/// through [AgentAuthorization.allow], which the bridge copies into
/// [AgentCommandContext.meta] under [metaPrincipal], [metaPrincipalId],
/// [metaRole], and [metaGroups]:
///
/// ```dart
/// AgentBridge.instance.configure(
///   enabled: true,
///   authorizer: AgentTokenAuthorizer(
///     principals: AgentPrincipalResolver(verifier: myVerifier),
///   ),
/// );
/// ```
class AgentTokenAuthorizer extends AgentAuthorizer {
  /// Creates an authorizer that gates every request on a verified token.
  ///
  /// Set [requireAuthenticationForDiscovery] to `false` to let an unauthenticated
  /// caller run `ping` and `describe` — useful when an agent must discover the
  /// application before the user has consented — while still requiring a token
  /// for `state` and `invoke`. Discovery is gated by default because the command
  /// catalog describes the application's capabilities.
  const AgentTokenAuthorizer({
    required this.principals,
    this.requireAuthenticationForDiscovery = true,
    this.requireAuthenticationForState = true,
    this.roleCheck = defaultRoleCheck,
  });

  /// Verifies tokens and caches the resulting principals.
  final AgentPrincipalResolver principals;

  /// Reports whether `ping` and `describe` require a verified token.
  final bool requireAuthenticationForDiscovery;

  /// Reports whether `state` requires a verified token.
  ///
  /// `state` exposes on-screen values, so it is gated by default even though it
  /// resolves to no command.
  final bool requireAuthenticationForState;

  /// Decides whether a principal satisfies a command's required role.
  final AgentRoleCheck roleCheck;

  /// Names the meta key carrying the serialized principal.
  static const String metaPrincipal = 'principal';

  /// Names the meta key carrying the principal identifier.
  static const String metaPrincipalId = 'principalId';

  /// Names the meta key carrying the principal's global role.
  static const String metaRole = 'role';

  /// Names the meta key carrying the principal's per-group roles.
  static const String metaGroups = 'groups';

  /// Names the role that satisfies every [AgentCommand.requiresRole] check.
  static const String superRole = 'admin';

  /// Verifies the token on [request] and checks it against [command].
  ///
  /// Denies with [AgentErrorCode.unauthorized] when the token is missing,
  /// invalid, or expired, and when the principal does not hold the role the
  /// command requires. Discovery methods, which resolve to no [command], are
  /// gated by [requireAuthenticationForDiscovery].
  @override
  Future<AgentAuthorization> authorize(
    AgentRequest request, {
    AgentCommand? command,
  }) async {
    final token = AgentPrincipalResolver.tokenFromRequest(request);
    final principal = await principals.resolve(token);
    if (principal == null) {
      if (command == null && !_authenticationRequiredFor(request.method)) {
        return const AgentAuthorization.allow();
      }
      return const AgentAuthorization.deny(
        'A valid bearer token is required. Send it as the "auth" parameter of '
        'the request.',
      );
    }
    final requiredRole = command?.requiresRole;
    if (requiredRole != null &&
        requiredRole.isNotEmpty &&
        !roleCheck(principal, requiredRole)) {
      return AgentAuthorization.deny(
        'Command "${command!.id}" requires the "$requiredRole" role.',
        code: AgentErrorCode.unauthorized,
      );
    }
    return AgentAuthorization.allow(
      meta: <String, dynamic>{
        metaPrincipal: principal.toJson(),
        metaPrincipalId: principal.id,
        metaRole: principal.role,
        metaGroups: principal.groups,
      },
    );
  }

  /// Reports whether [method] must present a token when no command is resolved.
  bool _authenticationRequiredFor(String method) {
    if (method == 'state') return requireAuthenticationForState;
    return requireAuthenticationForDiscovery;
  }

  /// Reports whether [principal] satisfies [requiredRole] by the default rules.
  ///
  /// The rules follow the role model used across Fabric applications, in order:
  /// the [superRole] `admin` always passes; an exact match against
  /// [AgentPrincipal.role] passes; a requirement written as `<group>-<role>`
  /// passes when the principal holds `<role>` in `<group>`; and finally a bare
  /// requirement passes when the principal holds that role in any group. Hosts
  /// with a different model pass their own [AgentRoleCheck].
  static bool defaultRoleCheck(AgentPrincipal principal, String requiredRole) {
    if (principal.role == superRole) return true;
    if (principal.role == requiredRole) return true;
    final separator = requiredRole.indexOf('-');
    if (separator > 0) {
      final group = requiredRole.substring(0, separator);
      final role = requiredRole.substring(separator + 1);
      if (principal.groups[group] == role) return true;
      if (principal.groups[group] == superRole) return true;
    }
    return principal.groups.values.contains(requiredRole);
  }
}
