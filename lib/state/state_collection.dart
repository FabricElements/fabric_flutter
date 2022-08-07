library fabric_flutter;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'state_shared.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateCollection extends StateShared {
  StateCollection();

  /// [initialized] after snapshot is requested the first time

  /// More at [query]
  Query<Map<String, dynamic>>? baseQuery;

  /// Collection Reference
  /// FirebaseFirestore.instance.collection('example')
  set query(Query<Map<String, dynamic>>? reference) {
    if (reference != baseQuery) clear();
    if (reference == baseQuery) return;
    baseQuery = reference;
    if (reference != null) {
      _listen();
    }
  }

  /// Firestore Document Stream Reference
  Stream<QuerySnapshot>? get _streamReference {
    return baseQuery?.snapshots();
  }

  /// Listen for document changes
  void _listen() {
    if (initialized) return;
    initialized = true;
    bool isValid = false;
    try {
      _streamReference?.listen((snapshot) {
        List<QueryDocumentSnapshot> dataDocs = snapshot.docs;
        data = dataDocs.isNotEmpty ? dataDocs : null;
        notifyListeners();
      }, cancelOnError: true).onError((e) {
        isValid = false;
        error = e?.toString();
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

  /// Stop listening for changes
  void _drain() async {
    try {
      await _streamReference?.drain();
    } catch (error) {
      //
    }
  }

  /// Clear document data
  void clear({bool notify = false}) {
    _drain();
    initialized = false;
    baseQuery = null;
    data = null;
    error = null;
    clearAfter();
    if (notify) notifyListeners();
  }
}
