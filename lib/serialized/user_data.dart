import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helper/utils.dart';

part 'user_data.g.dart';

/// Onboarding Object
@JsonSerializable(explicitToJson: true)
class UserDataOnboarding {
  @JsonKey(defaultValue: false, includeIfNull: true)
  final bool avatar;
  @JsonKey(defaultValue: false, includeIfNull: true)
  final bool name;
  @JsonKey(defaultValue: false, includeIfNull: true)
  final bool terms;

  UserDataOnboarding(
    this.avatar,
    this.name,
    this.terms,
  );

  factory UserDataOnboarding.fromJson(Map<String, dynamic>? json) =>
      _$UserDataOnboardingFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$UserDataOnboardingToJson(this);
}

/// Loan from loan service
@JsonSerializable(explicitToJson: true)
class UserData {
  /// User [avatar] URL
  @JsonKey(
    defaultValue: 'https://images.unsplash.com/photo-1547679904-ac76451d1594',
    includeIfNull: true,
  )
  final String avatar;

  /// User Creation Time: [created]
  @JsonKey(
    fromJson: Utils.timestampFromJsonDefault,
    toJson: Utils.timestampToJsonDefault,
    includeIfNull: true,
    defaultValue: null,
  )
  final DateTime created;

  /// [email] used for authentication
  @JsonKey(defaultValue: '', includeIfNull: true)
  final String email;

  /// Firebase Cloud Messaging [fcm] token https://firebase.google.com/docs/cloud-messaging
  @JsonKey(includeIfNull: true, defaultValue: null)
  final String? fcm;

  /// User [id]
  @JsonKey(includeIfNull: true, defaultValue: null)
  final String? id;

  /// User [name] = [nameFirst] + [nameLast]
  @JsonKey(defaultValue: '', includeIfNull: true)
  final String name;

  /// [nameFirst] First Name
  @JsonKey(defaultValue: '', includeIfNull: true)
  final String nameFirst;

  /// [nameInitials] = [nameFirst] + [nameLast] first characters
  @JsonKey(defaultValue: '', includeIfNull: true)
  final String nameInitials;

  /// [nameLast] Last Name
  @JsonKey(defaultValue: '', includeIfNull: true)
  final String nameLast;

  /// [language]
  @JsonKey(defaultValue: 'en', includeIfNull: true)
  final String language;

  /// User [onboarding] journey
  @JsonKey(includeIfNull: true, defaultValue: null)
  final UserDataOnboarding onboarding;

  /// Last time the user was ping: [ping]
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

  /// User [role]
  @JsonKey(defaultValue: 'user', includeIfNull: true)
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
  final DateTime updated;

  /// Optional [username]
  @JsonKey(includeIfNull: true)
  final String? username;

  UserData(
    this.avatar,
    this.created,
    this.email,
    this.fcm,
    this.id,
    this.name,
    this.nameFirst,
    this.nameInitials,
    this.nameLast,
    this.language,
    this.onboarding,
    this.phone,
    this.ping,
    this.role,
    this.updated,
    this.username,
  ) : presence = Utils.getPresence(ping);

  factory UserData.fromJson(Map<String, dynamic>? json) =>
      _$UserDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$UserDataToJson(this);
}
