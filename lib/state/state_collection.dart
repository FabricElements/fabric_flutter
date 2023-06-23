import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'state_shared.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
abstract class StateCollection extends StateShared {
  StateCollection();

  @override
  bool paginate = true;

  /// More at [query]
  Query? baseQuery;

  /// Stop listening for changes
  Future<bool> cancel() async {
    clear();
    if (_streamSubscription != null) {
      try {
        await _streamSubscription!.cancel();
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
    loading = true;
    cancel().then((_) {
      if (reference != null) {
        baseQuery = reference;
        clear();
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
    if (baseQuery == null) return;
    _streamSubscription =
        baseQuery!.limit(limit * page).snapshots().listen((snapshot) {
      initialized = true;
      data = [];

      /// Default totalCount depending on the page
      totalCount = snapshot.size;
      if (totalCount > 0) {
        List<Map<String, dynamic>> items = [];
        for (var doc in snapshot.docs) {
          final item = doc;
          Map<String, dynamic> tempData = item.data() as Map<String, dynamic>;
          tempData['id'] = item.id;
          items.add(tempData);
        }
        data = items;
      }
      Future.delayed(const Duration(seconds: 2)).then((_) {
        loading = false;
        notifyListeners();
      });
    }, onError: (e) {
      clear();
      data = [];
      error = e?.toString();
      loading = false;
    });
  }

  /// async function to process request
  @override
  Future<dynamic> call({
    bool ignoreDuplicatedCalls = false,
    bool notify = false,
  }) async {
    if (loading) return;
    loading = true;
    print('Calling next: $canPaginate page: $page');
    initialized = false;
    await _streamSubscription?.cancel();
    _listen();
  }
}
