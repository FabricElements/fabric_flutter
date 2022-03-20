import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'state_shared.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateDocument extends StateShared {
  StateDocument();

  /// [initialized] after snapshot is requested the first time

  /// More at [id]
  String? _documentId;

  /// Set document [id]
  set id(String? id) {
    if (id != _documentId) clear();
    if (id == _documentId) return;
    _documentId = id;
    if (id != null) {
      _listen();
    }
  }

  /// Get Firestore Document [id]
  String? get id => _documentId;

  /// Collection ID
  String? collection;

  /// Firestore Document Reference
  DocumentReference<Map<String, dynamic>>? get _documentReference {
    if (id == null || collection == null) return null;
    return FirebaseFirestore.instance.collection(collection!).doc(id);
  }

  /// Firestore Document Stream Reference
  Stream<DocumentSnapshot>? get _streamReference {
    return _documentReference?.snapshots();
  }

  /// Listen for document changes
  void _listen() {
    if (initialized) return;
    initialized = true;
    bool isValid = false;
    try {
      _streamReference?.listen((DocumentSnapshot snapshot) {
        String snapshotID = snapshot.id;
        isValid = snapshot.exists && snapshotID == _documentId;
        data = null;
        if (!isValid) {
          return;
        }
        Map<String, dynamic> _tempData =
            snapshot.data() as Map<String, dynamic>;
        _tempData['id'] = snapshotID;
        data = _tempData;
        notifyListeners();
      }, cancelOnError: true).onError((e) {
        isValid = false;
        error = e != null ? e.toString() : null;
        data = null;
        notifyListeners();
      });
    } catch (e) {
      if (isValid) {
        data = null;
      }
      error = e.toString();
      notifyListeners();
    }
  }

  /// Update Firestore Document
  Future<void> update(Map<String, dynamic> newData) {
    return _documentReference!.update(newData);
  }

  /// Set Merge Firestore Document
  Future<void> set(Map<String, dynamic> newData, {bool merge = false}) {
    return _documentReference!.set(newData, SetOptions(merge: merge));
  }

  /// Stop listening for changes
  void _drain() async {
    try {
      await _streamReference?.drain();
    } catch (error) {}
  }

  /// Clear document data
  void clear({bool notify = false}) {
    _drain();
    initialized = false;
    _documentId = null;
    data = null;
    error = null;
    clearAfter();
    if (notify) notifyListeners();
  }
}
