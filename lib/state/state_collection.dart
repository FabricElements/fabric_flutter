import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'state_shared.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
abstract class StateCollection extends StateShared {
  StateCollection();

  @override
  bool get paginate => true;

  /// More at [query]
  Query? baseQuery;

  /// Stop listening for changes
  Future<bool> cancel() async {
    clear(notify: true);
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
    if (loading) return;
    final oldReference = ({reference?.parameters ?? {}}).toString().hashCode;
    final newReference = ({baseQuery?.parameters ?? {}}).toString().hashCode;
    if (newReference == oldReference) return;
    initialized = false;
    loading = true;
    cancel().then((_) {
      if (reference != null) {
        baseQuery = reference;
        _listen();
      } else {
        loading = false;
        data = null;
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
      loading = false;
      data = null;

      /// Default totalCount depending on the page
      totalCount = snapshot.size;
      if (totalCount > 0) {
        List<Map<String, dynamic>> items = [];
        for (var doc in snapshot.docs) {
          final item = doc;
          items.add({
            ...item.data() as Map<String, dynamic>,
            'id': item.id,
          });
        }
        data = items;
      } else {
        data = [];
      }
    }, onError: (e) {
      clear();
      data = null;
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
    initialized = false;
    await _streamSubscription?.cancel();
    _listen();
  }
}
