class UserRoles {
  /// roleFromData Return an user role using [group]
  static String roleFromData({
    Map<String, dynamic>? compareData,
    String? group,
    String? role,

    /// Returns the role without the [group] prefix
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
