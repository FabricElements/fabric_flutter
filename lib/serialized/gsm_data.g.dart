// GENERATED CODE - DO NOT MODIFY BY HAND

part of fabric_flutter;

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GSMData _$GSMDataFromJson(Map<String, dynamic> json) => GSMData(
      segments: json['segments'] as int,
      charsLeft: json['charsLeft'] as int,
      charSet: $enumDecode(_$CharSetEnumMap, json['charSet']),
      parts: (json['parts'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$GSMDataToJson(GSMData instance) => <String, dynamic>{
      'segments': instance.segments,
      'charsLeft': instance.charsLeft,
      'charSet': _$CharSetEnumMap[instance.charSet]!,
      'parts': instance.parts,
    };

const _$CharSetEnumMap = {
  CharSet.unicode: 'unicode',
  CharSet.gsm: 'gsm',
};
