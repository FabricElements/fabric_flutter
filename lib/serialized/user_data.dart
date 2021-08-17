import 'package:json_annotation/json_annotation.dart';

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
  @JsonKey(
      defaultValue:
          "https://images.unsplash.com/photo-1547679904-ac76451d1594?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=500&h=500&q=80",
      includeIfNull: true)
  final String avatar;
  @JsonKey(includeIfNull: true)
  final DateTime? created;
  @JsonKey(defaultValue: "", includeIfNull: true)
  final String email;
  @JsonKey(includeIfNull: true, defaultValue: null)
  final String id;
  @JsonKey(defaultValue: "", includeIfNull: true)
  final String name;
  @JsonKey(defaultValue: "", includeIfNull: true)
  final String nameFirst;
  @JsonKey(defaultValue: "", includeIfNull: true)
  final String nameInitials;
  @JsonKey(defaultValue: "", includeIfNull: true)
  final String nameLast;
  @JsonKey(defaultValue: "en", includeIfNull: true)
  final String language;
  @JsonKey(includeIfNull: true)
  final UserDataOnboarding onboarding;
  @JsonKey(defaultValue: "", includeIfNull: true)
  final String phone;
  @JsonKey(includeIfNull: true, defaultValue: [])
  final List<String> tokens;
  @JsonKey(includeIfNull: true)
  final DateTime? updated;
  @JsonKey(includeIfNull: true)
  final String? username;

  UserData(
    this.avatar,
    this.created,
    this.email,
    this.id,
    this.name,
    this.nameFirst,
    this.nameInitials,
    this.nameLast,
    this.language,
    this.onboarding,
    this.phone,
    this.tokens,
    this.updated,
    this.username,
  );

  factory UserData.fromJson(Map<String, dynamic> json) =>
      _$UserDataFromJson(json);

  Map<String, dynamic> toJson() => _$UserDataToJson(this);
}
