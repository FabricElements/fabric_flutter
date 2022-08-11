// GENERATED CODE - DO NOT MODIFY BY HAND

part of fabric_flutter;

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
    created: Utils.timestampFromJsonDefault(json['created'] as Timestamp?),
    updated: Utils.timestampFromJsonDefault(json['updated'] as Timestamp?),
    backup: json['backup'] as bool? ?? false,
  );
}

Map<String, dynamic> _$BaseFirestoreToJson(BaseFirestore instance) =>
    <String, dynamic>{
      'id': instance.id,
      'updated': Utils.timestampUpdate(instance.updated),
      'created': Utils.timestampToJsonDefault(instance.created),
      'backup': Utils.boolFalse(instance.backup),
    };
