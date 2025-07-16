// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gsm_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GSMData _$GSMDataFromJson(Map<String, dynamic> json) => GSMData(
  text: json['text'] as String,
  segments: (json['segments'] as num).toInt(),
  charsLeft: (json['charsLeft'] as num).toInt(),
  charSet: $enumDecode(_$CharSetEnumMap, json['charSet']),
  parts: (json['parts'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$GSMDataToJson(GSMData instance) => <String, dynamic>{
  'text': instance.text,
  'segments': instance.segments,
  'charsLeft': instance.charsLeft,
  'charSet': _$CharSetEnumMap[instance.charSet]!,
  'parts': instance.parts,
};

const _$CharSetEnumMap = {CharSet.unicode: 'unicode', CharSet.gsm: 'gsm'};
