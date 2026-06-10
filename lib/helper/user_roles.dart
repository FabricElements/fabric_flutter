/// Resolves user-role labels from stored role and group data.
///
/// This helper keeps role formatting consistent anywhere the app needs to map a
/// raw user record into a displayable or comparable role string.
class UserRoles {
  /// Returns a role string derived from [compareData], [group], and [role].
  ///
  /// When [group] is present and exists inside `compareData['groups']`, the
  /// result is prefixed with the group name unless [clean] is `true`. If group
  /// data is unavailable, the helper falls back to `compareData['role']`, then
  /// [role], and finally `'user'`.
  static String roleFromData({
    Map<String, dynamic>? compareData,
    String? group,
    String? role,

    /// Returns the role without the [group] prefix.
    bool clean = false,
  }) {
    String roleDefault = compareData?['role'] ?? role ?? 'user';
    if (group == null || compareData == null) {
      return roleDefault;
    }

    /// Get role and access level
    Map<dynamic, dynamic> levelRole = compareData['groups'] ?? {};
    if (levelRole.containsKey(group)) {
      String baseRole = levelRole[group];
      if (clean) return baseRole;
      roleDefault = '$group-$baseRole';
    }
    return roleDefault;
  }
}
