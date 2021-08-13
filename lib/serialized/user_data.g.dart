// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDataOnboarding _$UserDataOnboardingFromJson(Map<String, dynamic> json) =>
    UserDataOnboarding(
      json['name'] as bool? ?? false,
      json['avatar'] as bool? ?? false,
    );

Map<String, dynamic> _$UserDataOnboardingToJson(UserDataOnboarding instance) =>
    <String, dynamic>{
      'name': instance.name,
      'avatar': instance.avatar,
    };

UserData _$UserDataFromJson(Map<String, dynamic> json) => UserData(
      json['id'] as String,
      json['name'] as String? ?? '',
      UserDataOnboarding.fromJson(json['onboarding'] as Map<String, dynamic>?),
      (json['tokens'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
      json['avatar'] as String? ??
          'https://images.unsplash.com/photo-1547679904-ac76451d1594?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=500&h=500&q=80',
      json['email'] as String? ?? '',
      json['phone'] as String? ?? '',
    );

Map<String, dynamic> _$UserDataToJson(UserData instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'avatar': instance.avatar,
      'email': instance.email,
      'phone': instance.phone,
      'onboarding': instance.onboarding.toJson(),
      'tokens': instance.tokens,
    };
