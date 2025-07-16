// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDataOnboarding _$UserDataOnboardingFromJson(Map<String, dynamic> json) =>
    UserDataOnboarding(
      main: json['main'] as bool? ?? false,
      avatar: json['avatar'] as bool? ?? false,
      name: json['name'] as bool? ?? false,
      terms: json['terms'] as bool? ?? false,
    );

Map<String, dynamic> _$UserDataOnboardingToJson(UserDataOnboarding instance) =>
    <String, dynamic>{
      'avatar': instance.avatar,
      'name': instance.name,
      'terms': instance.terms,
      'main': instance.main,
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
  onboarding:
      json['onboarding'] == null
          ? null
          : UserDataOnboarding.fromJson(
            json['onboarding'] as Map<String, dynamic>?,
          ),
  phone: json['phone'] as String?,
  ping: FirestoreHelper.timestampFromJson(json['ping']),
  username: json['username'] as String?,
  email: json['email'] as String?,
  fcm: json['fcm'] as String?,
  id: json['id'],
  role: json['role'] as String? ?? 'unknown',
  groups:
      (json['groups'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  roles:
      (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  avatar: json['avatar'] as String?,
  firstName: json['firstName'] as String?,
  lastName: json['lastName'] as String?,
  language: json['language'] as String?,
  password: json['password'] as String?,
  bcId: json['bcId'] as String?,
  bsId: json['bsId'] as String?,
  bsiId: json['bsiId'] as String?,
  theme:
      $enumDecodeNullable(
        _$ThemeModeEnumMap,
        json['theme'],
        unknownValue: ThemeMode.light,
      ) ??
      ThemeMode.light,
  links:
      json['links'] == null
          ? null
          : InterfaceLinks.fromJson(json['links'] as Map<String, dynamic>?),
  os: $enumDecodeNullable(_$UserOSEnumMap, json['os']) ?? UserOS.unknown,
  country: json['country'] as String?,
);

Map<String, dynamic> _$UserDataToJson(UserData instance) => <String, dynamic>{
  if (instance.avatar case final value?) 'avatar': value,
  if (instance.email case final value?) 'email': value,
  if (instance.fcm case final value?) 'fcm': value,
  if (instance.id case final value?) 'id': value,
  if (instance.firstName case final value?) 'firstName': value,
  if (instance.lastName case final value?) 'lastName': value,
  if (instance.language case final value?) 'language': value,
  if (instance.onboarding?.toJson() case final value?) 'onboarding': value,
  if (instance.links?.toJson() case final value?) 'links': value,
  'os': _$UserOSEnumMap[instance.os]!,
  if (instance.phone case final value?) 'phone': value,
  if (instance.password case final value?) 'password': value,
  'role': instance.role,
  'groups': instance.groups,
  'roles': instance.roles,
  if (instance.username case final value?) 'username': value,
  'theme': _$ThemeModeEnumMap[instance.theme]!,
  'country': instance.country,
};

const _$ThemeModeEnumMap = {
  ThemeMode.system: 'system',
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
};

const _$UserOSEnumMap = {
  UserOS.android: 'android',
  UserOS.ios: 'ios',
  UserOS.macos: 'macos',
  UserOS.linux: 'linux',
  UserOS.web: 'web',
  UserOS.fuchsia: 'fuchsia',
  UserOS.windows: 'windows',
  UserOS.unknown: 'unknown',
};
