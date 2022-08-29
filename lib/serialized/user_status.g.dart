// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserStatus _$UserStatusFromJson(Map<String, dynamic> json) => UserStatus(
      signedIn: json['signedIn'] as bool? ?? false,
      admin: json['admin'] as bool? ?? false,
      role: json['role'] as String? ?? 'user',
      uid: json['uid'] as String?,
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
  return val;
}
