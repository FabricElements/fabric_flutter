import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helper/firestore_helper.dart';
import '../helper/utils.dart';

part 'base_db.g.dart';

/// BaseFirestore serialized data
@JsonSerializable(explicitToJson: true)
class BaseFirestore {
  /// -
  @JsonKey(required: true)
  String id;

  /// Last time the user was updated
  @JsonKey(
    fromJson: FirestoreHelper.timestampFromJsonDefault,
    toJson: FirestoreHelper.timestampUpdate,
    includeIfNull: true,
  )
  DateTime? updated;

  /// Creation time
  @JsonKey(
    fromJson: FirestoreHelper.timestampFromJsonDefault,
    toJson: FirestoreHelper.timestampToJsonDefault,
    includeIfNull: true,
  )
  DateTime? created;

  @JsonKey(includeIfNull: true, toJson: Utils.boolFalse)
  bool backup;

  BaseFirestore({
    required this.id,
    this.created,
    this.updated,
    this.backup = false,
  });

  factory BaseFirestore.fromJson(Map<String, dynamic>? json) =>
      _$BaseFirestoreFromJson(json ?? {});

  /// Default toJson
  Map<String, dynamic> toJson() => _$BaseFirestoreToJson(this);

  /// Update document
  Future<void> update({required String collection}) {
    assert(id.isNotEmpty && collection.isNotEmpty,
        'collection and document id are required');
    Map<String, dynamic> jsonData = toJson();
    jsonData.remove('id');
    jsonData.remove('created');
    return FirebaseFirestore.instance
        .collection(collection)
        .doc(id)
        .update(jsonData);
  }

  /// Update document
  Future<void> delete({required String collection}) {
    assert(id.isNotEmpty && collection.isNotEmpty,
        'collection and document id are required');
    return FirebaseFirestore.instance.collection(collection).doc(id).delete();
  }

  /// Set document
  Future<void> set({required String collection, bool merge = false}) {
    assert(id.isNotEmpty && collection.isNotEmpty,
        'collection and document id are required');
    Map<String, dynamic> jsonData = toJson();
    jsonData.remove('id');
    return FirebaseFirestore.instance
        .collection(collection)
        .doc(id)
        .set(jsonData, SetOptions(merge: merge));
  }

  /// Add document to collection
  Future<String> add({
    required String collection,
    bool numerical = false,
  }) async {
    assert(collection.isNotEmpty, 'collection is required');
    CollectionReference ref = FirebaseFirestore.instance.collection(collection);
    Map<String, dynamic> jsonData = toJson();
    jsonData.remove('id');
    // Filter FieldValue.delete values
    jsonData.removeWhere((key, value) => value == FieldValue.delete());

    /// Handle incremental id's
    if (numerical) {
      // Get last document id
      final last =
          await ref.orderBy('created', descending: true).limit(1).get();
      late int lastId;
      if (last.size == 0) {
        // Set to '0' if collection is empty
        lastId = 0;
      } else {
        // Parse last document id
        lastId = int.parse(last.docs.single.id);
      }
      // Get new document id
      String newId = (lastId + 1).toString();
      // Save and return id
      await ref.doc(newId).set(jsonData);
      return newId;
    }

    // Save and return id
    final result = await ref.add(jsonData);
    return result.id;
  }
}
