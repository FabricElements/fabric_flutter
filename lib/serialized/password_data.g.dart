// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'password_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PasswordData _$PasswordDataFromJson(Map<String, dynamic> json) => PasswordData(
  currentPassword: json['currentPassword'] as String,
  newPassword: json['newPassword'] as String,
);

Map<String, dynamic> _$PasswordDataToJson(PasswordData instance) =>
    <String, dynamic>{
      'currentPassword': instance.currentPassword,
      'newPassword': instance.newPassword,
    };
