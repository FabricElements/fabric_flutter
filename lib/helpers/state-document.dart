import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateDocument extends ChangeNotifier {
  StateDocument();

  String _documentId;
  Map<String, dynamic> _data = {};
  DocumentReference _documentReference;
  Stream<DocumentSnapshot> _streamReference;
  String collection = "demo";

  /// Set document [id]
  set id(String id) {
    _drain();
    reset();
    _data = {};
    _documentId = id;
    if (id != null) {
      _documentReference =
          Firestore.instance.collection(collection).document(id);
      _streamReference = _documentReference.snapshots();
      _listen();
    }
    notifyListeners();
  }

  /// Listen for document changes
  void _listen() {
    _data = {};
    try {
      _streamReference.listen((snapshot) {
        if (snapshot.exists) {
          _data = snapshot.data;
        } else {
          _data = {};
        }
        _data["id"] = snapshot.documentID;
        notifyListeners();
      });
    } catch (error) {
      _data = {};
      print(error.message);
      notifyListeners();
    }
  }

  Future<void> update(Map<String, dynamic> newData) {
    return _documentReference.updateData(newData);
  }

  Future<void> set(Map<String, dynamic> newData, {bool merge = false}) {
    return _documentReference.setData(newData, merge: merge);
  }

  /// Get document [id]
  String get id => _documentId;

  /// Return document [data]
  Map<String, dynamic> get data {
    if (_documentId != null && _data.isEmpty) {
      _listen();
    }
    return _data;
  }

  /// Stop listening for changes
  void _drain() async {
    try {
      if (id != null && _streamReference != null) {
        await _streamReference.drain();
      }
    } catch (error) {
//      print("snapshot: $error");
    }
  }

  /// Default function call every time the id changes.
  /// Override this function to add custom features for your state.
  void reset() {}

  /// Clear document data
  void clear() {
    _drain();
    _documentId = null;
    _data = {};
    reset();
    notifyListeners();
  }
}
