import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_status.g.dart';

@JsonSerializable(explicitToJson: true)
class UserStatus {
  @JsonKey(includeIfNull: false)
  final bool signedIn;
  @JsonKey(includeIfNull: false)
  final bool admin;
  @JsonKey(includeIfNull: true)
  final String role;
  @JsonKey(includeIfNull: false)
  dynamic uid;

  /// Language
  final String language;

  /// Theme Mode
  final ThemeMode theme;

  /// Internet connection status
  final bool connected;
  final bool connectionChanged;
  final String? connectedTo;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final bool ready;

  UserStatus({
    this.signedIn = false,
    this.admin = false,
    this.role = 'user',
    this.language = 'en',
    this.theme = ThemeMode.system,
    this.uid,
    this.connected = true,
    this.connectionChanged = false,
    this.connectedTo,
    this.ready = false,
  });

  factory UserStatus.fromJson(Map<String, dynamic>? json) =>
      _$UserStatusFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$UserStatusToJson(this);
}
