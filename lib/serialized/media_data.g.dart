// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaData _$MediaDataFromJson(Map<String, dynamic> json) => MediaData(
  data: json['data'] as String,
  contentType: json['contentType'] as String,
  extension: json['extension'] as String,
  fileName: json['fileName'] as String,
  size: (json['size'] as num).toInt(),
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
);

Map<String, dynamic> _$MediaDataToJson(MediaData instance) => <String, dynamic>{
  'data': instance.data,
  'contentType': instance.contentType,
  'extension': instance.extension,
  'fileName': instance.fileName,
  'height': instance.height,
  'width': instance.width,
  'size': instance.size,
};
