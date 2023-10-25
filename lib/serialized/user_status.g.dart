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
      theme: $enumDecodeNullable(_$ThemeModeEnumMap, json['theme']) ??
          ThemeMode.system,
      uid: json['uid'],
      connected: json['connected'] as bool? ?? true,
      connectionChanged: json['connectionChanged'] as bool? ?? false,
      connectedTo: json['connectedTo'] as String?,
    );

Map<String, dynamic> _$UserStatusToJson(UserStatus instance) {
  final val = <String, dynamic>{
    'signedIn': instance.signedIn,
    'admin': instance.admin,
    'role': instance.role,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('uid', instance.uid);
  val['language'] = instance.language;
  val['theme'] = _$ThemeModeEnumMap[instance.theme]!;
  val['connected'] = instance.connected;
  val['connectionChanged'] = instance.connectionChanged;
  val['connectedTo'] = instance.connectedTo;
  return val;
}

const _$ThemeModeEnumMap = {
  ThemeMode.system: 'system',
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
};
