// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDataOnboarding _$UserDataOnboardingFromJson(Map<String, dynamic> json) =>
    $checkedCreate('UserDataOnboarding', json, ($checkedConvert) {
      final val = UserDataOnboarding(
        main: $checkedConvert('main', (v) => v as bool? ?? false),
        avatar: $checkedConvert('avatar', (v) => v as bool? ?? false),
        name: $checkedConvert('name', (v) => v as bool? ?? false),
        terms: $checkedConvert('terms', (v) => v as bool? ?? false),
      );
      return val;
    });

Map<String, dynamic> _$UserDataOnboardingToJson(UserDataOnboarding instance) =>
    <String, dynamic>{
      'avatar': instance.avatar,
      'name': instance.name,
      'terms': instance.terms,
      'main': instance.main,
    };

InterfaceLinks _$InterfaceLinksFromJson(Map<String, dynamic> json) =>
    $checkedCreate('InterfaceLinks', json, ($checkedConvert) {
      final val = InterfaceLinks(
        behance: $checkedConvert('behance', (v) => v as String?),
        dribbble: $checkedConvert('dribbble', (v) => v as String?),
        facebook: $checkedConvert('facebook', (v) => v as String?),
        instagram: $checkedConvert('instagram', (v) => v as String?),
        linkedin: $checkedConvert('linkedin', (v) => v as String?),
        tiktok: $checkedConvert('tiktok', (v) => v as String?),
        x: $checkedConvert('x', (v) => v as String?),
        youtube: $checkedConvert('youtube', (v) => v as String?),
        website: $checkedConvert('website', (v) => v as String?),
      );
      return val;
    });

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

UserData _$UserDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('UserData', json, ($checkedConvert) {
  final val = UserData(
    onboarding: $checkedConvert(
      'onboarding',
      (v) => v == null
          ? null
          : UserDataOnboarding.fromJson(v as Map<String, dynamic>?),
    ),
    phone: $checkedConvert('phone', (v) => v as String?),
    ping: $checkedConvert('ping', (v) => FirestoreHelper.timestampFromJson(v)),
    username: $checkedConvert('username', (v) => v as String?),
    email: $checkedConvert('email', (v) => v as String?),
    fcm: $checkedConvert('fcm', (v) => v == null ? const [] : _fcmFromJson(v)),
    id: $checkedConvert('id', (v) => v),
    role: $checkedConvert('role', (v) => v as String? ?? 'unknown'),
    groups: $checkedConvert(
      'groups',
      (v) =>
          (v as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
    ),
    roles: $checkedConvert(
      'roles',
      (v) =>
          (v as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
    ),
    avatar: $checkedConvert('avatar', (v) => v as String?),
    firstName: $checkedConvert('firstName', (v) => v as String?),
    lastName: $checkedConvert('lastName', (v) => v as String?),
    language: $checkedConvert('language', (v) => v as String?),
    password: $checkedConvert('password', (v) => v as String?),
    bcId: $checkedConvert('bcId', (v) => v as String?),
    bsId: $checkedConvert('bsId', (v) => v as String?),
    bsiId: $checkedConvert('bsiId', (v) => v as String?),
    theme: $checkedConvert(
      'theme',
      (v) =>
          $enumDecodeNullable(
            _$ThemeModeEnumMap,
            v,
            unknownValue: ThemeMode.light,
          ) ??
          ThemeMode.light,
    ),
    links: $checkedConvert(
      'links',
      (v) => v == null
          ? null
          : InterfaceLinks.fromJson(v as Map<String, dynamic>?),
    ),
    os: $checkedConvert(
      'os',
      (v) => $enumDecodeNullable(_$UserOSEnumMap, v) ?? UserOS.unknown,
    ),
    country: $checkedConvert('country', (v) => v as String?),
    visualDensity: $checkedConvert(
      'visualDensity',
      (v) =>
          $enumDecodeNullable(
            _$CustomVisualDensityEnumMap,
            v,
            unknownValue: CustomVisualDensity.adaptive,
          ) ??
          CustomVisualDensity.adaptive,
    ),
  );
  return val;
});

Map<String, dynamic> _$UserDataToJson(UserData instance) => <String, dynamic>{
  'avatar': ?instance.avatar,
  'email': ?instance.email,
  'id': ?instance.id,
  'firstName': ?instance.firstName,
  'lastName': ?instance.lastName,
  'language': ?instance.language,
  'onboarding': ?instance.onboarding?.toJson(),
  'links': ?instance.links?.toJson(),
  'os': _$UserOSEnumMap[instance.os]!,
  'phone': ?instance.phone,
  'password': ?instance.password,
  'role': instance.role,
  'groups': instance.groups,
  'roles': instance.roles,
  'username': ?instance.username,
  'theme': _$ThemeModeEnumMap[instance.theme]!,
  'country': instance.country,
  'visualDensity': _$CustomVisualDensityEnumMap[instance.visualDensity]!,
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

const _$CustomVisualDensityEnumMap = {
  CustomVisualDensity.adaptive: 'adaptive',
  CustomVisualDensity.compact: 'compact',
  CustomVisualDensity.comfortable: 'comfortable',
  CustomVisualDensity.standard: 'standard',
  CustomVisualDensity.large: 'large',
};
