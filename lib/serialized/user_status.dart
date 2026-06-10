import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_status.g.dart';

/// Enumerates the app-specific visual density presets available to a user.
///
/// These values are stored separately from Flutter's built-in density classes so
/// user preferences can be serialized in a stable, platform-independent way.
enum CustomVisualDensity {
  /// Lets the application decide density based on the current platform.
  adaptive,

  /// Uses a tighter layout to fit more information on screen.
  compact,

  /// Uses a slightly relaxed layout for readability.
  comfortable,

  /// Uses the default density expected by Material widgets.
  standard,

  /// Uses extra spacing for touch-heavy or accessibility-focused layouts.
  large,
}

/// Captures serialized user session and preference state.
///
/// This model combines authentication flags with UI preferences so the app can
/// restore a user's environment after refreshes, sign-ins, or persisted cache
/// reads.
@JsonSerializable(explicitToJson: true)
class UserStatus {
  /// Indicates whether the user is currently authenticated.
  @JsonKey(includeIfNull: false)
  final bool signedIn;

  /// Indicates whether the user has administrative privileges.
  @JsonKey(includeIfNull: false)
  final bool admin;

  /// Stores the user's application role.
  @JsonKey(includeIfNull: true)
  final String role;

  /// Stores the backend-specific user identifier.
  ///
  /// This value is `dynamic` because different authentication providers may use
  /// numeric, string, or structured identifiers.
  @JsonKey(includeIfNull: false)
  dynamic uid;

  /// Stores the preferred language code for localization.
  @JsonKey(includeIfNull: false)
  final String language;

  /// Stores the preferred Material theme mode.
  @JsonKey(includeIfNull: false, unknownEnumValue: ThemeMode.light)
  final ThemeMode theme;

  /// Stores the preferred application visual density preset.
  @JsonKey(includeIfNull: false, unknownEnumValue: CustomVisualDensity.adaptive)
  final CustomVisualDensity visualDensity;

  /// Indicates whether the current user state is ready for UI consumption.
  ///
  /// This flag helps the app distinguish between a default placeholder state and
  /// a fully initialized session loaded from storage or the backend.
  bool ready;

  /// Creates a serialized user status snapshot.
  UserStatus({
    this.signedIn = false,
    this.admin = false,
    this.role = 'user',
    this.language = 'en',
    this.theme = ThemeMode.light,
    this.uid,
    this.ready = false,
    this.visualDensity = CustomVisualDensity.adaptive,
  });

  /// Builds [UserStatus] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty map so callers can safely restore a
  /// default status when no persisted data exists.
  factory UserStatus.fromJson(Map<String, dynamic>? json) =>
      _$UserStatusFromJson(json ?? {});

  /// Converts this user status into JSON.
  Map<String, dynamic> toJson() => _$UserStatusToJson(this);
}
