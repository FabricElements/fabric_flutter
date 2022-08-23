library fabric_flutter;

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
