// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDataOnboarding _$UserDataOnboardingFromJson(Map<String, dynamic> json) =>
    UserDataOnboarding(
      avatar: json['avatar'] as bool? ?? false,
      name: json['name'] as bool? ?? false,
      terms: json['terms'] as bool? ?? false,
    );

Map<String, dynamic> _$UserDataOnboardingToJson(UserDataOnboarding instance) =>
    <String, dynamic>{
      'avatar': instance.avatar,
      'name': instance.name,
      'terms': instance.terms,
    };

UserData _$UserDataFromJson(Map<String, dynamic> json) => UserData(
      onboarding: json['onboarding'] == null
          ? null
          : UserDataOnboarding.fromJson(
              json['onboarding'] as Map<String, dynamic>?),
      phone: json['phone'] as String?,
      ping: FirestoreHelper.timestampFromJson(json['ping'] as Timestamp?),
      username: json['username'] as String?,
      email: json['email'] as String?,
      fcm: json['fcm'] as String?,
      id: json['id'],
      role: json['role'] as String? ?? 'user',
      groups: (json['groups'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      avatar: json['avatar'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      language: json['language'] as String? ?? 'en',
      password: json['password'] as String?,
      accounts: (json['accounts'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
    );

Map<String, dynamic> _$UserDataToJson(UserData instance) {
  final val = <String, dynamic>{
    'avatar': instance.avatar,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('email', instance.email);
  val['fcm'] = instance.fcm;
  writeNotNull('id', instance.id);
  writeNotNull('firstName', instance.firstName);
  writeNotNull('lastName', instance.lastName);
  val['language'] = instance.language;
  writeNotNull('onboarding', instance.onboarding?.toJson());
  writeNotNull('phone', instance.phone);
  writeNotNull('password', instance.password);
  val['role'] = instance.role;
  val['groups'] = instance.groups;
  val['username'] = instance.username;
  return val;
}
