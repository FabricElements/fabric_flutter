import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'state_shared.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
abstract class StateCollection extends StateShared {
  StateCollection();

  /// More at [query]
  Query? baseQuery;

  /// Stop listening for changes
  Future<bool> cancel() async {
    clear();
    if (_streamSubscription != null) {
      try {
        await _streamSubscription!.cancel();
        print('canceled: ${baseQuery?.parameters.toString()}');
        baseQuery = null;
        return true;
      } catch (error) {
        //
      }
    }
    return false;
  }

  /// Collection Reference
  /// FirebaseFirestore.instance.collection('example')
  set query(Query? reference) {
    if (reference?.parameters.toString() == baseQuery?.parameters.toString()) {
      return;
    }
    initialized = false;
    cancel().then((_) {
      if (reference != null) {
        baseQuery = reference;
        _listen();
      } else {
        data = [];
      }
    });
  }

  /// Firestore Document Stream Reference
  StreamSubscription<QuerySnapshot<Object?>>? _streamSubscription;

  /// Listen for document changes
  void _listen() {
    if (initialized) return;
    initialized = true;
    _streamSubscription = baseQuery?.snapshots().listen((snapshot) {
      clear();
      data = [];
      initialized = true;
      if (snapshot.size > 0) {
        List<Map<String, dynamic>> items = [];
        for (var doc in snapshot.docs) {
          final item = doc;
          Map<String, dynamic> tempData = item.data() as Map<String, dynamic>;
          tempData['id'] = item.id;
          items.add(tempData);
        }
        data = items;
      }
    }, onError: (e) {
      clear();
      data = [];
      error = e?.toString();
    });
  }
}
