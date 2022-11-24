import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helper/firestore_helper.dart';
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
    fromJson: FirestoreHelper.timestampFromJsonDefault,
    toJson: FirestoreHelper.timestampToJsonDefault,
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

  /// User name = [firstName] + [lastName]
  @JsonKey(includeIfNull: true)
  final String name;

  /// [firstName] First Name
  @JsonKey(includeIfNull: false)
  String firstName;

  /// Name abbreviation
  /// [abbr] = [firstName] + [lastName] first characters
  @JsonKey(includeIfNull: false)
  final String abbr;

  /// [lastName] Last Name
  @JsonKey(includeIfNull: false)
  String lastName;

  /// [language]
  @JsonKey(includeIfNull: true)
  String language;

  /// User onboarding journey
  @JsonKey(includeIfNull: false)
  final UserDataOnboarding? onboarding;

  /// Last time the user was ping
  @JsonKey(
    fromJson: FirestoreHelper.timestampFromJson,
    toJson: FirestoreHelper.timestampToJson,
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
    fromJson: FirestoreHelper.timestampFromJsonDefault,
    toJson: FirestoreHelper.timestampToJsonDefault,
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
    this.avatar = 'https://images.unsplash.com/photo-1547679904-ac76451d1594',
    this.firstName = '',
    this.lastName = '',
    this.language = 'en',
  })  : presence = Utils.getPresence(ping),
        abbr = Utils.nameAbbreviation(
          name: name,
          firstName: firstName,
          lastName: lastName,
        );

  factory UserData.fromJson(Map<String, dynamic>? json) =>
      _$UserDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$UserDataToJson(this);
}
