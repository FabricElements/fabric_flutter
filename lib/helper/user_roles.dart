class UserRoles {
  /// roleFromData Return an user role using [groupId]
  static String roleFromData({
    Map<String, dynamic>? compareData,
    String? group,
    String? groupId,
    String? role,

    /// Returns the role without the [group] prefix
    bool clean = false,
  }) {
    String roleDefault = compareData?['role'] ?? role ?? 'user';
    if (group == null || groupId == null || compareData == null) {
      return roleDefault;
    }

    /// Get role and access level
    Map<dynamic, dynamic> levelRole = compareData[group] ?? {};
    if (levelRole.containsKey(groupId)) {
      String baseRole = levelRole[groupId];
      if (clean) return baseRole;
      roleDefault = '$group-$baseRole';
    }
    return roleDefault;
  }
}
