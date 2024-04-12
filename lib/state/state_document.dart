import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'state_shared.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
abstract class StateDocument extends StateShared {
  StateDocument();

  /// More at [ref]
  DocumentReference? baseRef;

  /// Stop listening for changes
  Future<void> cancel({bool clear = false}) async {
    baseRef = null;
    if (_streamSubscription != null) {
      try {
        await _streamSubscription!.cancel();
      } catch (error) {
        //
      }
    }
    if (clear) this.clear(notify: true);
  }

  /// Collection Reference
  /// FirebaseFirestore.instance.collection('example')
  set ref(DocumentReference? reference) {
    if (loading) return;
    final oldReference = baseRef?.path ?? '';
    final newReference = reference?.path ?? '';
    if (newReference.hashCode == oldReference.hashCode) return;
    initialized = false;
    loading = true;
    baseRef = reference;
    cancel().then((_) {
      if (reference != null) {
        baseRef = reference;
        _listen();
      } else {
        loading = false;
        data = null;
        initialized = false;
      }
    }).catchError((error) {
      loading = false;
      data = null;
      initialized = false;
    });
  }

  /// Get document reference
  DocumentReference? get ref => baseRef;

  /// Firestore Document Stream Reference
  StreamSubscription<DocumentSnapshot<Object?>>? _streamSubscription;

  /// Listen for document changes
  void _listen() {
    if (initialized) return;
    initialized = true;
    if (baseRef == null) return;
    _streamSubscription = baseRef!.snapshots().listen((snapshot) {
      initialized = true;
      loading = false;
      if (snapshot.exists) {
        data = {
          ...snapshot.data() as Map<String, dynamic>,
          'id': snapshot.id,
        };
      } else {
        data = null;
      }
    }, onError: (e) {
      clear();
      data = null;
      error = e?.toString();
      loading = false;
      initialized = false;
    });
  }

  /// async function to process request
  @override
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async {
    if (loading) return;
    loading = true;
    initialized = false;
    await _streamSubscription?.cancel();
    _listen();
  }

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
