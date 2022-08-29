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
      created: FirestoreHelper.timestampFromJsonDefault(
          json['created'] as Timestamp?),
      updated: FirestoreHelper.timestampFromJsonDefault(
          json['updated'] as Timestamp?),
      name: json['name'] as String? ?? '',
      onboarding: json['onboarding'] == null
          ? null
          : UserDataOnboarding.fromJson(
              json['onboarding'] as Map<String, dynamic>?),
      phone: json['phone'] as String? ?? '',
      ping: FirestoreHelper.timestampFromJson(json['ping'] as Timestamp?),
      username: json['username'] as String?,
      email: json['email'] as String? ?? '',
      fcm: json['fcm'] as String?,
      id: json['id'] as String?,
      role: json['role'] as String? ?? 'user',
      nameInitials: json['nameInitials'] as String? ?? '',
      avatar: json['avatar'] as String? ??
          'https://images.unsplash.com/photo-1547679904-ac76451d1594',
      nameFirst: json['nameFirst'] as String? ?? '',
      nameLast: json['nameLast'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
    );

Map<String, dynamic> _$UserDataToJson(UserData instance) {
  final val = <String, dynamic>{
    'avatar': instance.avatar,
    'created': FirestoreHelper.timestampToJsonDefault(instance.created),
    'email': instance.email,
    'fcm': instance.fcm,
    'id': instance.id,
    'name': instance.name,
    'nameFirst': instance.nameFirst,
    'nameInitials': instance.nameInitials,
    'nameLast': instance.nameLast,
    'language': instance.language,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('onboarding', instance.onboarding?.toJson());
  val['ping'] = FirestoreHelper.timestampToJson(instance.ping);
  val['phone'] = instance.phone;
  val['role'] = instance.role;
  val['updated'] = FirestoreHelper.timestampToJsonDefault(instance.updated);
  val['username'] = instance.username;
  return val;
}
