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

InterfaceLinks _$InterfaceLinksFromJson(Map<String, dynamic> json) =>
    InterfaceLinks(
      behance: json['behance'] as String?,
      dribbble: json['dribbble'] as String?,
      facebook: json['facebook'] as String?,
      instagram: json['instagram'] as String?,
      linkedin: json['linkedin'] as String?,
      tiktok: json['tiktok'] as String?,
      x: json['x'] as String?,
      youtube: json['youtube'] as String?,
      website: json['website'] as String?,
    );

Map<String, dynamic> _$InterfaceLinksToJson(InterfaceLinks instance) =>
    <String, dynamic>{
      'behance': instance.behance,
      'dribbble': instance.dribbble,
      'facebook': instance.facebook,
      'instagram': instance.instagram,
      'linkedin': instance.linkedin,
      'tiktok': instance.tiktok,
      'x': instance.x,
      'website': instance.website,
      'youtube': instance.youtube,
    };

UserData _$UserDataFromJson(Map<String, dynamic> json) => UserData(
      onboarding: json['onboarding'] == null
          ? null
          : UserDataOnboarding.fromJson(
              json['onboarding'] as Map<String, dynamic>?),
      phone: json['phone'] as String?,
      ping: FirestoreHelper.timestampFromJson(json['ping']),
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
      bcId: json['bcId'] as String?,
      bsId: json['bsId'] as String?,
      bsiId: json['bsiId'] as String?,
      brightness:
          $enumDecodeNullable(_$BrightnessEnumMap, json['brightness']) ??
              Brightness.light,
      links: json['links'] == null
          ? null
          : InterfaceLinks.fromJson(json['links'] as Map<String, dynamic>?),
    );

Map<String, dynamic> _$UserDataToJson(UserData instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('avatar', instance.avatar);
  writeNotNull('email', instance.email);
  writeNotNull('fcm', instance.fcm);
  writeNotNull('id', instance.id);
  writeNotNull('firstName', instance.firstName);
  writeNotNull('lastName', instance.lastName);
  val['language'] = instance.language;
  writeNotNull('onboarding', instance.onboarding?.toJson());
  writeNotNull('links', instance.links?.toJson());
  writeNotNull('phone', instance.phone);
  writeNotNull('password', instance.password);
  val['role'] = instance.role;
  val['groups'] = instance.groups;
  writeNotNull('username', instance.username);
  val['brightness'] = _$BrightnessEnumMap[instance.brightness]!;
  return val;
}

const _$BrightnessEnumMap = {
  Brightness.dark: 'dark',
  Brightness.light: 'light',
};
