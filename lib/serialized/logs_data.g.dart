// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logs_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LogsData _$LogsDataFromJson(Map<String, dynamic> json) => LogsData(
  id: json['id'],
  text: json['text'] as String?,
  timestamp: Utils.dateTimeFromJson(json['timestamp'] as String?),
  data: json['data'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$LogsDataToJson(LogsData instance) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'timestamp': ?Utils.dateToJson(instance.timestamp),
  'data': instance.data,
};
