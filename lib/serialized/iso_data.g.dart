// GENERATED CODE - DO NOT MODIFY BY HAND

part of fabric_flutter;

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ISOLanguage _$ISOLanguageFromJson(Map<String, dynamic> json) => ISOLanguage(
      alpha2: json['alpha2'] as String,
      alpha3: json['alpha3'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nativeName: json['nativeName'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🌐',
    );

Map<String, dynamic> _$ISOLanguageToJson(ISOLanguage instance) =>
    <String, dynamic>{
      'alpha2': instance.alpha2,
      'alpha3': instance.alpha3,
      'name': instance.name,
      'nativeName': instance.nativeName,
      'emoji': instance.emoji,
    };
