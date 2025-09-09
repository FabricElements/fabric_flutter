// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserStatus _$UserStatusFromJson(Map<String, dynamic> json) => UserStatus(
  signedIn: json['signedIn'] as bool? ?? false,
  admin: json['admin'] as bool? ?? false,
  role: json['role'] as String? ?? 'user',
  language: json['language'] as String? ?? 'en',
  theme:
      $enumDecodeNullable(
        _$ThemeModeEnumMap,
        json['theme'],
        unknownValue: ThemeMode.light,
      ) ??
      ThemeMode.light,
  uid: json['uid'],
  connected: json['connected'] as bool? ?? true,
  connectionChanged: json['connectionChanged'] as bool? ?? false,
  connectedTo: json['connectedTo'] as String?,
  ready: json['ready'] as bool? ?? false,
);

Map<String, dynamic> _$UserStatusToJson(UserStatus instance) =>
    <String, dynamic>{
      'signedIn': instance.signedIn,
      'admin': instance.admin,
      'role': instance.role,
      'uid': ?instance.uid,
      'language': instance.language,
      'theme': _$ThemeModeEnumMap[instance.theme]!,
      'connected': instance.connected,
      'connectionChanged': instance.connectionChanged,
      'connectedTo': instance.connectedTo,
      'ready': instance.ready,
    };

const _$ThemeModeEnumMap = {
  ThemeMode.system: 'system',
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
};
