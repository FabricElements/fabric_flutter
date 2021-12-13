import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateDocument extends ChangeNotifier {
  StateDocument();

  /// [_called] after snapshot is requested the first time
  bool _called = false;

  /// [_initialized] after data is called the first time
  bool _initialized = false;

  /// More at [id]
  String? _documentId;

  /// More at [data]
  Map<String, dynamic> _data = {};

  /// Firestore Document Reference
  DocumentReference<Map<String, dynamic>>? get _documentReference {
    if (id == null || collection == null) return null;
    return FirebaseFirestore.instance.collection(collection!).doc(id);
  }

  /// Firestore Document Stream Reference
  Stream<DocumentSnapshot>? get _streamReference {
    return _documentReference?.snapshots();
  }

  /// More at [callback]
  VoidCallback? _callback;

  /// More at [_onUpdate]
  VoidCallback? _onUpdate;

  /// Collection ID
  String? collection;

  /// Set document [id]
  set id(String? id) {
    if (id != _documentId) clear();
    if (id == _documentId) return;
    _documentId = id;
    if (id != null) {
      _listen();
    }
  }

  /// Listen for document changes
  void _listen() {
    if (_called) return;
    _called = true;
    bool isValid = false;
    try {
      _streamReference?.listen((DocumentSnapshot snapshot) {
        String snapshotID = snapshot.id;
        isValid = snapshot.exists && snapshotID == _documentId;
        _data = {};
        if (!isValid) {
          return;
        }
        _data = snapshot.data() as Map<String, dynamic>;
        _data["id"] = snapshotID;
        if (_initialized && _onUpdate != null) _onUpdate!();
        _initialized = true;
        if (_callback != null) _callback!();
        notifyListeners();
      }, cancelOnError: true).onError((error) {
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
    return _documentReference!.update(newData);
  }

  /// Set Merge Firestore Document
  Future<void> set(Map<String, dynamic> newData, {bool merge = false}) {
    return _documentReference!.set(newData, SetOptions(merge: merge));
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
      await _streamReference?.drain();
    } catch (error) {}
  }

  /// Override [clearAfter] for a custom implementation
  /// It is called on the [clear]
  void clearAfter() {}

  /// Clear document data
  void clear({bool notify = false}) {
    _drain();
    _initialized = false;
    _called = false;
    _documentId = null;
    _data = {};
    _callback = null;
    _onUpdate = null;
    clearAfter();
    if (notify) notifyListeners();
  }

  /// Callback on successful load
  set callback(VoidCallback _function) => _callback = _function;

  /// [onUpdate] is called every time data is updated
  set onUpdate(VoidCallback? _function) => _onUpdate = _function;
}
