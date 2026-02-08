import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_status.g.dart';

/// Custom visual density options
enum CustomVisualDensity { adaptive, compact, comfortable, standard, large }

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
  @JsonKey(includeIfNull: false)
  final String language;

  /// Theme Mode
  @JsonKey(includeIfNull: false, unknownEnumValue: ThemeMode.light)
  final ThemeMode theme;

  /// Visual Density
  /// Custom visual density for the user interface
  @JsonKey(includeIfNull: false, unknownEnumValue: CustomVisualDensity.adaptive)
  final CustomVisualDensity visualDensity;

  /// User is ready
  bool ready;

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

  factory UserStatus.fromJson(Map<String, dynamic>? json) =>
      _$UserStatusFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$UserStatusToJson(this);
}
