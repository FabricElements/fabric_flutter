// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_db.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BaseFirestore _$BaseFirestoreFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const ['id'],
  );
  return BaseFirestore(
    id: json['id'] as String,
    created: FirestoreHelper.timestampFromJsonDefault(json['created']),
    updated: FirestoreHelper.timestampFromJsonDefault(json['updated']),
    backup: json['backup'] as bool? ?? false,
  );
}

Map<String, dynamic> _$BaseFirestoreToJson(BaseFirestore instance) =>
    <String, dynamic>{
      'id': instance.id,
      'updated': FirestoreHelper.timestampUpdate(instance.updated),
      'created': FirestoreHelper.timestampToJsonDefault(instance.created),
      'backup': Utils.boolFalse(instance.backup),
    };
