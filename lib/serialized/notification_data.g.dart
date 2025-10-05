// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationData _$NotificationDataFromJson(Map<String, dynamic> json) =>
    NotificationData(
      title: json['title'] as String?,
      body: json['body'] as String?,
      imageUrl: json['imageUrl'] as String?,
      type: json['type'] as String?,
      path: json['path'] as String?,
      clear: json['clear'] as bool? ?? false,
      os:
          $enumDecodeNullable(
            _$UserOSEnumMap,
            json['os'],
            unknownValue: UserOS.unknown,
          ) ??
          UserOS.unknown,
      typeString: json['typeString'] as String?,
      duration: (json['duration'] as num?)?.toInt() ?? 5,
      account: json['account'] as String?,
      id: json['id'] as String?,
      origin: json['origin'] as String?,
    );

Map<String, dynamic> _$NotificationDataToJson(NotificationData instance) =>
    <String, dynamic>{
      'title': instance.title,
      'body': instance.body,
      'imageUrl': instance.imageUrl,
      'type': instance.type,
      'path': instance.path,
      'clear': instance.clear,
      'os': _$UserOSEnumMap[instance.os]!,
      'typeString': instance.typeString,
      'duration': instance.duration,
      'account': ?instance.account,
      'id': ?instance.id,
      'origin': ?instance.origin,
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
