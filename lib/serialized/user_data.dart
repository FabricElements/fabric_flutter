import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helper/firestore_helper.dart';
import '../helper/utils.dart';

part 'user_data.g.dart';

enum UserPresence { active, inactive, away }

/// User Device OS
enum UserOS { android, ios, macos, linux, web, fuchsia, windows, unknown }

/// Custom visual density options
enum CustomVisualDensity { adaptive, compact, comfortable, standard, large }

/// Onboarding Object
@JsonSerializable(explicitToJson: true)
class UserDataOnboarding {
  @JsonKey(includeIfNull: true)
  final bool avatar;
  @JsonKey(includeIfNull: true)
  final bool name;
  @JsonKey(includeIfNull: true)
  final bool terms;
  @JsonKey(includeIfNull: true)
  final bool main;

  UserDataOnboarding({
    this.main = false,
    this.avatar = false,
    this.name = false,
    this.terms = false,
  });

  factory UserDataOnboarding.fromJson(Map<String, dynamic>? json) =>
      _$UserDataOnboardingFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$UserDataOnboardingToJson(this);
}

/// InterfaceLinks Object
@JsonSerializable(explicitToJson: true)
class InterfaceLinks {
  @JsonKey(includeIfNull: true)
  String? behance;
  @JsonKey(includeIfNull: true)
  String? dribbble;
  @JsonKey(includeIfNull: true)
  String? facebook;
  @JsonKey(includeIfNull: true)
  String? instagram;
  @JsonKey(includeIfNull: true)
  String? linkedin;
  @JsonKey(includeIfNull: true)
  String? tiktok;
  @JsonKey(includeIfNull: true)
  String? x;
  @JsonKey(includeIfNull: true)
  String? website;
  @JsonKey(includeIfNull: true)
  String? youtube;

  InterfaceLinks({
    this.behance,
    this.dribbble,
    this.facebook,
    this.instagram,
    this.linkedin,
    this.tiktok,
    this.x,
    this.youtube,
    this.website,
  });

  factory InterfaceLinks.fromJson(Map<String, dynamic>? json) =>
      _$InterfaceLinksFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$InterfaceLinksToJson(this);
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

  /// User Links
  @JsonKey(includeIfNull: false)
  InterfaceLinks? links;

  /// User device type
  @JsonKey(includeIfNull: true, defaultValue: UserOS.unknown)
  UserOS os;

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

  @JsonKey(includeIfNull: false)
  List<String> roles;

  /// User presence
  final UserPresence presence;

  /// Optional username
  @JsonKey(includeIfNull: false)
  String? username;

  /// Billing Customer ID
  @JsonKey(includeToJson: false)
  final String? bcId;

  /// Billing Subscription ID
  @JsonKey(includeToJson: false)
  final String? bsId;

  /// Billing Subscription Item ID to track events
  @JsonKey(includeToJson: false)
  final String? bsiId;

  /// Theme Mode
  @JsonKey(
    includeIfNull: false,
    defaultValue: ThemeMode.light,
    unknownEnumValue: ThemeMode.light,
  )
  final ThemeMode theme;

  /// Country code
  String? country;

  /// Visual Density
  /// Custom visual density for the user interface
  @JsonKey(includeIfNull: false, unknownEnumValue: CustomVisualDensity.adaptive)
  final CustomVisualDensity visualDensity;

  UserData({
    this.onboarding,
    this.phone,
    this.ping,
    this.username,
    this.email,
    this.fcm,
    this.id,
    this.role = 'unknown',
    this.groups = const {},
    this.roles = const [],
    this.avatar,
    this.firstName,
    this.lastName,
    this.language,
    this.password,
    this.bcId,
    this.bsId,
    this.bsiId,
    this.theme = ThemeMode.light,
    this.links,
    this.os = UserOS.unknown,
    this.country,
    this.visualDensity = CustomVisualDensity.adaptive,
  }) : presence = Utils.getPresence(ping),
       name = Utils.nameFromParts(firstName: firstName, lastName: lastName),
       abbr = Utils.nameAbbreviation(firstName: firstName, lastName: lastName);

  factory UserData.fromJson(Map<String, dynamic>? json) =>
      _$UserDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$UserDataToJson(this);
}
