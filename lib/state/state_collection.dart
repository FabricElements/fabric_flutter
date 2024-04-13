import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'state_shared.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
abstract class StateCollection extends StateShared {
  StateCollection();

  @override
  bool get paginate => true;

  @override
  bool get canPaginate => true;

  /// More at [query]
  Query? baseQuery;

  /// Stop listening for changes
  Future<void> cancel({bool clear = false}) async {
    baseQuery = null;
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
  set query(Query? reference) {
    if (loading) return;
    final newReference =
        ({reference?.limit(limit * page).parameters ?? {}}).toString().hashCode;
    final oldReference = ({baseQuery?.parameters ?? {}}).toString().hashCode;
    if (oldReference == newReference) return;
    baseQuery = reference;
    _streamSubscription?.cancel();
    super.clear(notify: false);
    data = [];
  }

  _softClear({bool notify = false}) {
    if (notify) {
      data = [];
    } else {
      privateData = null;
    }
    loading = false;
    initialized = false;
  }

  /// Firestore Document Stream Reference
  StreamSubscription<QuerySnapshot<Object?>>? _streamSubscription;

  /// Make call and listen for changes
  @override
  Future<dynamic> listen() async {
    if (loading) return data;
    if (initialized) return data;
    _softClear(notify: false);
    loading = true;
    await _streamSubscription?.cancel();
    if (baseQuery == null) {
      loading = false;
      data = [];
      return data;
    }
    initialized = true;
    try {
      _streamSubscription =
          baseQuery!.limit(limit * page).snapshots().listen((snapshot) {
        loading = false;

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
        super.clear();
        data = [];
        error = e?.toString();
      });
    } catch (e) {
      super.clear(notify: false);
      data = [];
      error = e.toString();
    }
    return data;
  }

  /// On page change
  @override
  void onPageChange(int newPage) async {
    _softClear(notify: false);
  }

  @override
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async {
    if (_streamSubscription != null) return listen();
    if (loading) return data;
    if (initialized) return data;
    _softClear(notify: false);
    loading = true;
    await _streamSubscription?.cancel();
    if (baseQuery == null) {
      loading = false;
      data = [];
      return data;
    }
    initialized = true;
    try {
      final snapshot = await baseQuery!.limit(limit * page).get();
      loading = false;
      // Default totalCount depending on the page
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
    } catch (e) {
      super.clear(notify: false);
      data = [];
      error = e.toString();
    }
    return data;
  }

  /// Clear data
  @override
  void clear({bool notify = false}) {
    super.clear(notify: notify);
    baseQuery = null;
    data = [];
  }
}
