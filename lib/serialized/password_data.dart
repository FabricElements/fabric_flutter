import 'package:json_annotation/json_annotation.dart';

part 'password_data.g.dart';

/// Stores the credentials required for a password change request.
///
/// Keeping the current and replacement values together makes it easier to pass a
/// single serialized object through validation, transport, and API layers.
@JsonSerializable(explicitToJson: true)
class PasswordData {
  /// Stores the user's existing password for verification.
  String currentPassword;

  /// Stores the new password the user wants to apply.
  String newPassword;

  /// Creates serialized password change data.
  PasswordData({required this.currentPassword, required this.newPassword});

  /// Builds [PasswordData] from serialized JSON.
  ///
  /// A `null` payload is treated as empty input so optional password payloads can
  /// still be deserialized safely by the caller.
  factory PasswordData.fromJson(Map<String, dynamic>? json) =>
      _$PasswordDataFromJson(json ?? {});

  /// Converts this password payload into JSON.
  Map<String, dynamic> toJson() => _$PasswordDataToJson(this);
}
