import 'package:json_annotation/json_annotation.dart';

import '../helper/firestore_helper.dart';
import '../helper/utils.dart';

part 'user_data.g.dart';

enum UserPresence {
  active,
  inactive,
  away,
}

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
  /// User avatar URL
  @JsonKey(includeIfNull: false)
  final String? avatar;

  /// email used for authentication
  @JsonKey(includeIfNull: false)
  String? email;

  /// Firebase Cloud Messaging [fcm] token https://firebase.google.com/docs/cloud-messaging
  @JsonKey(includeIfNull: false)
  final String? fcm;

  /// User id
  @JsonKey(includeIfNull: false)
  final dynamic id;

  /// User name = [firstName] + [lastName]
  @JsonKey(includeIfNull: true)
  final String name;

  /// First Name
  @JsonKey(includeIfNull: false)
  String? firstName;

  /// Name abbreviation
  /// abbr = [firstName] + [lastName] first characters
  @JsonKey(includeIfNull: false)
  final String abbr;

  /// Last Name
  @JsonKey(includeIfNull: false)
  String? lastName;

  /// Language
  @JsonKey(includeIfNull: false)
  String? language;

  /// User onboarding journey
  @JsonKey(includeIfNull: false)
  final UserDataOnboarding? onboarding;

  /// Last time the user was ping
  @JsonKey(
    fromJson: FirestoreHelper.timestampFromJson,
    // toJson: FirestoreHelper.timestampToJson,
    includeIfNull: true,
    defaultValue: null,
    includeToJson: false,
  )
  final DateTime? ping;

  /// phone used for authentication
  @JsonKey(includeIfNull: false)
  String? phone;

  /// password used for authentication
  @JsonKey(includeIfNull: false)
  String? password;

  /// User role
  @JsonKey(includeIfNull: true)
  String role;

  /// User role
  @JsonKey(includeIfNull: false)
  Map<String, String> groups;

  /// User presence
  final UserPresence presence;

  /// Account group with roles
  @JsonKey(includeToJson: false)
  final Map<String, String> accounts;

  /// Optional username
  @JsonKey(includeIfNull: false)
  String? username;

  /// Optional username
  @JsonKey(includeToJson: false)
  final String? customer;

  UserData({
    this.onboarding,
    this.phone,
    this.ping,
    this.username,
    this.email,
    this.fcm,
    this.id,
    this.role = 'user',
    this.groups = const {},
    this.avatar,
    this.firstName,
    this.lastName,
    this.language,
    this.password,
    this.accounts = const {},
    this.customer,
  })  : presence = Utils.getPresence(ping),
        name = Utils.nameFromParts(
          firstName: firstName,
          lastName: lastName,
        ),
        abbr = Utils.nameAbbreviation(
          firstName: firstName,
          lastName: lastName,
        );

  factory UserData.fromJson(Map<String, dynamic>? json) =>
      _$UserDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$UserDataToJson(this);
}
