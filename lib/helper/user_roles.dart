class UserRoles {
  /// [roleFromData] Return an user role using [groupId]
  static String roleFromData({
    Map<String, dynamic>? compareData,
    String? level,
    String? levelId,
    String? role,

    /// [clean] returns the role without the [level]
    bool clean = false,
  }) {
    String roleDefault = compareData?['role'] ?? role ?? 'user';
    if (level == null || levelId == null || compareData == null) {
      return roleDefault;
    }

    /// Get role and access level
    Map<dynamic, dynamic> levelRole = compareData[level] ?? {};
    if (levelRole.containsKey(levelId)) {
      String baseRole = levelRole[levelId];
      if (clean) return baseRole;
      roleDefault = '$level-$baseRole';
    }
    return roleDefault;
  }
}
