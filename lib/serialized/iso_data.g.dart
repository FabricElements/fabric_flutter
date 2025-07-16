// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iso_data.dart';

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

ISOCountry _$ISOCountryFromJson(Map<String, dynamic> json) => ISOCountry(
  capital: json['capital'] as String?,
  citizenship: json['citizenship'] as String?,
  countryCode: json['countryCode'] as String,
  currency: json['currency'] as String?,
  currencyCode: json['currencyCode'] as String?,
  currencySubUnit: json['currencySubUnit'] as String?,
  fullName: json['fullName'] as String?,
  alpha2: json['alpha2'] as String,
  alpha3: json['alpha3'] as String,
  name: json['name'] as String,
  regionCode: json['regionCode'] as String?,
  subRegionCode: json['subRegionCode'] as String?,
  eea: json['eea'] as bool? ?? false,
  callingCode: json['callingCode'] as String?,
  currencySymbol: json['currencySymbol'] as String?,
  flag: json['flag'] as String? ?? '🌐',
);

Map<String, dynamic> _$ISOCountryToJson(ISOCountry instance) =>
    <String, dynamic>{
      'capital': instance.capital,
      'citizenship': instance.citizenship,
      'countryCode': instance.countryCode,
      'currency': instance.currency,
      'currencyCode': instance.currencyCode,
      'currencySubUnit': instance.currencySubUnit,
      'fullName': instance.fullName,
      'alpha2': instance.alpha2,
      'alpha3': instance.alpha3,
      'name': instance.name,
      'regionCode': instance.regionCode,
      'subRegionCode': instance.subRegionCode,
      'eea': instance.eea,
      'callingCode': instance.callingCode,
      'currencySymbol': instance.currencySymbol,
      'flag': instance.flag,
    };
