library fabric_flutter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helper/utils.dart';

part 'user_data.g.dart';

/// Onboarding Object
@JsonSerializable(explicitToJson: true)
class UserDataOnboarding {
  @JsonKey(includeIfNull: true)
  final bool avatar;
  @JsonKey(includeIfNull: true)
  final bool name;
  @JsonKey(includeIfNull: true)
  final bool terms;

  UserDataOnboarding({
    this.avatar = false,
    this.name = false,
    this.terms = false,
  });

  factory UserDataOnboarding.fromJson(Map<String, dynamic>? json) =>
      _$UserDataOnboardingFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$UserDataOnboardingToJson(this);
}

/// Loan from loan service
@JsonSerializable(explicitToJson: true)
class UserData {
  /// User [avatar] URL
  @JsonKey(includeIfNull: true)
  final String avatar;

  /// User Creation Time: [created]
  @JsonKey(
    fromJson: Utils.timestampFromJsonDefault,
    toJson: Utils.timestampToJsonDefault,
    includeIfNull: true,
    defaultValue: null,
  )
  final DateTime? created;

  /// email used for authentication
  @JsonKey(includeIfNull: true)
  final String email;

  /// Firebase Cloud Messaging [fcm] token https://firebase.google.com/docs/cloud-messaging
  @JsonKey(includeIfNull: true)
  final String? fcm;

  /// User id
  @JsonKey(includeIfNull: true)
  final String? id;

  /// User name = [nameFirst] + [nameLast]
  @JsonKey(includeIfNull: true)
  final String name;

  /// [nameFirst] First Name
  @JsonKey(includeIfNull: false)
  String nameFirst;

  /// [nameInitials] = [nameFirst] + [nameLast] first characters
  @JsonKey(includeIfNull: false)
  final String nameInitials;

  /// [nameLast] Last Name
  @JsonKey(includeIfNull: false)
  String nameLast;

  /// [language]
  @JsonKey(includeIfNull: true)
  String language;

  /// User onboarding journey
  @JsonKey(includeIfNull: false)
  final UserDataOnboarding? onboarding;

  /// Last time the user was ping
  @JsonKey(
    fromJson: Utils.timestampFromJson,
    toJson: Utils.timestampToJson,
    includeIfNull: true,
    defaultValue: null,
  )
  final DateTime? ping;

  /// [phone] used for authentication
  @JsonKey(defaultValue: '', includeIfNull: true)
  final String phone;

  /// User role
  @JsonKey(includeIfNull: true)
  final String role;

  /// User [presence] (active, inactive, away)
  final String presence;

  /// Last time the user was updated: [updated]
  @JsonKey(
    fromJson: Utils.timestampFromJsonDefault,
    toJson: Utils.timestampToJsonDefault,
    includeIfNull: true,
    defaultValue: null,
  )
  final DateTime? updated;

  /// Optional [username]
  @JsonKey(includeIfNull: true)
  final String? username;

  UserData({
    this.created,
    this.updated,
    this.name = '',
    this.onboarding,
    this.phone = '',
    this.ping,
    this.username,
    this.email = '',
    this.fcm,
    this.id,
    this.role = 'user',
    this.nameInitials = '',
    this.avatar = 'https://images.unsplash.com/photo-1547679904-ac76451d1594',
    this.nameFirst = '',
    this.nameLast = '',
    this.language = 'en',
  }) : presence = Utils.getPresence(ping);

  factory UserData.fromJson(Map<String, dynamic>? json) =>
      _$UserDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$UserDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class UserStatus {
  @JsonKey(includeIfNull: false)
  bool signedIn;
  @JsonKey(includeIfNull: false)
  bool admin;
  @JsonKey(includeIfNull: true)
  String role;
  @JsonKey(includeIfNull: false)
  String? uid;

  UserStatus({
    this.signedIn = false,
    this.admin = false,
    this.role = 'user',
    this.uid,
  });

  factory UserStatus.fromJson(Map<String, dynamic>? json) =>
      _$UserStatusFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$UserStatusToJson(this);
}
