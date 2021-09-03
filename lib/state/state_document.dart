import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateDocument extends ChangeNotifier {
  StateDocument();

  /// More at [id]
  String? _documentId;

  /// More at [data]
  Map<String, dynamic> _data = {};

  /// Firestore Document Reference
  late DocumentReference<Map<String, dynamic>> _documentReference;

  /// Firestore Document Stream Reference
  Stream<DocumentSnapshot>? _streamReference;

  /// More at [callback]
  VoidCallback? _callback;

  /// Collection ID
  String collection = "demo";

  /// Set document [id]
  set id(String? id) {
    if (id != _documentId) clear();
    if (id == _documentId && _data.isNotEmpty) return;
    _documentId = id;
    if (id != null) {
      _documentReference =
          FirebaseFirestore.instance.collection(collection).doc(id);
      _streamReference = _documentReference.snapshots();
      _listen();
    }
  }

  /// Listen for document changes
  void _listen() {
    bool isValid = false;
    try {
      _streamReference!.listen((snapshot) {
        String snapshotID = snapshot.id;
        isValid = snapshot.exists && snapshotID == _documentId;
        _data = {};
        if (!isValid) {
          return;
        }
        _data = snapshot.data()! as Map<String, dynamic>;
        _data["id"] = snapshotID;
        notifyListeners();
        if (_callback != null) _callback!();
      }).onError((error) {
        print(error);
        isValid = false;
        _data = {};
        notifyListeners();
      });
    } catch (error) {
      if (isValid) {
        _data = {};
        notifyListeners();
      }
    }
  }

  /// Update Firestore Document
  Future<void> update(Map<String, dynamic> newData) {
    return _documentReference.update(newData);
  }

  /// Set Merge Firestore Document
  Future<void> set(Map<String, dynamic> newData, {bool merge = false}) {
    return _documentReference.set(newData, SetOptions(merge: merge));
  }

  /// Get Firestore Document [id]
  String? get id => _documentId;

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
        await _streamReference!.drain();
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
    _callback = null;
    reset();
    notifyListeners();
  }

  /// Callback on successful load
  set callback(VoidCallback _function) => _callback = _function;
}
