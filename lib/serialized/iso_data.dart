import 'package:json_annotation/json_annotation.dart';

part 'iso_data.g.dart';

@JsonSerializable(explicitToJson: true)
class ISOLanguage {
  final String alpha2;
  @JsonKey(includeIfNull: true)
  final String alpha3;
  final String name;
  final String nativeName;
  final String emoji;

  ISOLanguage({
    required this.alpha2,
    this.alpha3 = '',
    this.name = '',
    this.nativeName = '',
    this.emoji = '🌐',
  });

  factory ISOLanguage.fromJson(Map<String, dynamic>? json) =>
      _$ISOLanguageFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$ISOLanguageToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ISOCountry {
  final String? capital;
  final String? citizenship;
  final String countryCode;
  final String? currency;
  final String? currencyCode;
  final String? currencySubUnit;
  final String? fullName;
  final String alpha2;
  final String alpha3;
  final String name;
  final String? regionCode;
  final String? subRegionCode;
  final bool eea;
  final String? callingCode;
  final String? currencySymbol;
  final String flag;

  ISOCountry({
    this.capital,
    this.citizenship,
    required this.countryCode,
    this.currency,
    this.currencyCode,
    this.currencySubUnit,
    this.fullName,
    required this.alpha2,
    required this.alpha3,
    required this.name,
    this.regionCode,
    this.subRegionCode,
    this.eea = false,
    this.callingCode,
    this.currencySymbol,
    this.flag = '🌐',
  });

  factory ISOCountry.fromJson(Map<String, dynamic>? json) =>
      _$ISOCountryFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$ISOCountryToJson(this);
}
