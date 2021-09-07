// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_data.dart';

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
          'https://images.unsplash.com/photo-1547679904-ac76451d1594?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=500&h=500&q=80',
      json['email'] as String? ?? '',
      json['id'] as String?,
      json['name'] as String? ?? '',
      json['nameFirst'] as String? ?? '',
      json['nameInitials'] as String? ?? '',
      json['nameLast'] as String? ?? '',
      json['language'] as String? ?? 'en',
      UserDataOnboarding.fromJson(json['onboarding'] as Map<String, dynamic>?),
      json['phone'] as String? ?? '',
      json['role'] as String? ?? 'user',
      (json['tokens'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
      json['username'] as String?,
    );

Map<String, dynamic> _$UserDataToJson(UserData instance) => <String, dynamic>{
      'avatar': instance.avatar,
      'email': instance.email,
      'id': instance.id,
      'name': instance.name,
      'nameFirst': instance.nameFirst,
      'nameInitials': instance.nameInitials,
      'nameLast': instance.nameLast,
      'language': instance.language,
      'onboarding': instance.onboarding.toJson(),
      'phone': instance.phone,
      'role': instance.role,
      'tokens': instance.tokens,
      'username': instance.username,
    };
