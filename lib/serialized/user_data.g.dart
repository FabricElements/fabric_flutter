// GENERATED CODE - DO NOT MODIFY BY HAND

part of fabric_flutter;

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDataOnboarding _$UserDataOnboardingFromJson(Map<String, dynamic> json) =>
    UserDataOnboarding(
      json['avatar'] as bool? ?? false,
      json['name'] as bool? ?? false,
      json['terms'] as bool? ?? false,
    );

Map<String, dynamic> _$UserDataOnboardingToJson(UserDataOnboarding instance) =>
    <String, dynamic>{
      'avatar': instance.avatar,
      'name': instance.name,
      'terms': instance.terms,
    };

UserData _$UserDataFromJson(Map<String, dynamic> json) => UserData(
      json['avatar'] as String? ??
          'https://images.unsplash.com/photo-1547679904-ac76451d1594',
      Utils.timestampFromJsonDefault(json['created'] as Timestamp?),
      json['email'] as String? ?? '',
      json['fcm'] as String?,
      json['id'] as String?,
      json['name'] as String? ?? '',
      json['nameFirst'] as String? ?? '',
      json['nameInitials'] as String? ?? '',
      json['nameLast'] as String? ?? '',
      json['language'] as String? ?? 'en',
      UserDataOnboarding.fromJson(json['onboarding'] as Map<String, dynamic>?),
      json['phone'] as String? ?? '',
      Utils.timestampFromJson(json['ping'] as Timestamp?),
      json['role'] as String? ?? 'user',
      Utils.timestampFromJsonDefault(json['updated'] as Timestamp?),
      json['username'] as String?,
    );

Map<String, dynamic> _$UserDataToJson(UserData instance) => <String, dynamic>{
      'avatar': instance.avatar,
      'created': Utils.timestampToJsonDefault(instance.created),
      'email': instance.email,
      'fcm': instance.fcm,
      'id': instance.id,
      'name': instance.name,
      'nameFirst': instance.nameFirst,
      'nameInitials': instance.nameInitials,
      'nameLast': instance.nameLast,
      'language': instance.language,
      'onboarding': instance.onboarding.toJson(),
      'ping': Utils.timestampToJson(instance.ping),
      'phone': instance.phone,
      'role': instance.role,
      'updated': Utils.timestampToJsonDefault(instance.updated),
      'username': instance.username,
    };

UserStatus _$UserStatusFromJson(Map<String, dynamic> json) => UserStatus(
      signedIn: json['signedIn'] as bool? ?? false,
      admin: json['admin'] as bool? ?? false,
      role: json['role'] as String? ?? 'user',
    );

Map<String, dynamic> _$UserStatusToJson(UserStatus instance) =>
    <String, dynamic>{
      'signedIn': instance.signedIn,
      'admin': instance.admin,
      'role': instance.role,
    };
