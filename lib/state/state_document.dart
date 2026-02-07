import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import 'state_shared.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
abstract class StateDocument extends StateShared {
  StateDocument();

  /// More at [ref]
  DocumentReference? baseRef;

  /// Stop listening for changes
  Future<void> cancel({bool notify = false}) async {
    baseRef = null;
    if (_streamSubscription != null) {
      try {
        await _streamSubscription!.cancel();
      } catch (error) {
        //
      }
    }
    return clear(notify: notify);
  }

  /// Collection Reference
  /// FirebaseFirestore.instance.collection('example')
  set ref(DocumentReference? reference) {
    if (loading) return;
    final oldReference = baseRef?.path ?? '';
    final newReference = reference?.path ?? '';
    if (newReference == oldReference) return;
    _streamSubscription?.cancel();
    baseRef = reference;
    super.clear(notify: true);
  }

  /// Make call and listen for changes
  @override
  Future<dynamic> listen() async {
    if (loading) return data;
    if (initialized) return data;
    loading = true;
    await _streamSubscription?.cancel();
    super.clear(notify: false);
    if (baseRef == null) {
      super.notifyListeners();
      return data;
    }
    initialized = true;
    loading = true;
    data = null;
    try {
      _streamSubscription = baseRef!.snapshots().listen(
        (snapshot) {
          loading = false;
          if (snapshot.exists) {
            /// Compare data
            final newData = {
              ...snapshot.data() as Map<String, dynamic>,
              'id': snapshot.id,
            };
            if (privateData != null) {
              Map<String, dynamic> dataObjectMap = Map<String, dynamic>.from(
                newData,
              );
              Map<String, dynamic> privateDataMap = Map<String, dynamic>.from(
                privateData,
              );
              const keysToIgnoreFromNotification = [
                'updated',
                'created',
                'ping',
                'os',
                'backup',
                'fcm',
              ];
              // Remove keys that match with [keysToIgnoreFromNotification]
              dataObjectMap.removeWhere(
                (key, value) => keysToIgnoreFromNotification.contains(key),
              );
              privateDataMap.removeWhere(
                (key, value) => keysToIgnoreFromNotification.contains(key),
              );
              // Basic comparison
              if (dataObjectMap == privateDataMap) return;
              if (const DeepCollectionEquality().equals(
                dataObjectMap,
                privateDataMap,
              )) {
                return;
              }
            }

            /// Assign new data
            data = newData;
          } else {
            data = null;
          }
        },
        onError: (e) {
          initialized = false;
          loading = false;
          error = e?.toString();
        },
      );
    } catch (e) {
      initialized = false;
      loading = false;
      error = e.toString();
    }
    return data;
  }

  @override
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async {
    if (loading) return data;
    if (initialized) return data;
    loading = true;
    await _streamSubscription?.cancel();
    super.clear(notify: false);
    if (baseRef == null) {
      data = null;
      return data;
    }
    loading = true;
    try {
      initialized = true;
      final snapshot = await baseRef!.get();
      data = {...snapshot.data() as Map<String, dynamic>, 'id': snapshot.id};
    } catch (e) {
      initialized = false;
      loading = false;
      error = e.toString();
    }
    loading = false;
    return data;
  }

  /// Get document reference
  DocumentReference? get ref => baseRef;

  /// Firestore Document Stream Reference
  StreamSubscription<DocumentSnapshot<Object?>>? _streamSubscription;

  /// Update Firestore Document
  Future<void> update(Map<String, dynamic> newData) => baseRef!.update(newData);

  /// Set Merge Firestore Document
  Future<void> set(Map<String, dynamic> newData, {bool merge = false}) =>
      baseRef!.set(newData, SetOptions(merge: merge));

  /// Clear data
  @override
  void clear({bool notify = true}) {
    baseRef = null;
    super.clear(notify: notify);
  }
}
