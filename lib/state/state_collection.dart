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
  Future<void> cancel({bool notify = false}) async {
    baseQuery = null;
    if (_streamSubscription != null) {
      try {
        await _streamSubscription!.cancel();
      } catch (error) {
        //
      }
    }
    return clear(notify: notify);
  }

  bool isSameQuery(Query? reference) {
    final totalToFetch = limit * page;
    Query? newQuery = reference?.limit(totalToFetch);
    final newReference = ({newQuery?.parameters ?? {}}).toString().hashCode;
    final oldReference = ({query?.parameters ?? {}}).toString().hashCode;
    return oldReference == newReference;
  }

  bool isSameBaseQuery(Query? reference) {
    final newReference = ({reference?.parameters ?? {}}).toString().hashCode;
    final oldReference = ({baseQuery?.parameters ?? {}}).toString().hashCode;
    bool same = oldReference == newReference;
    if (!same) {
      super.clear(notify: !initialized);
    }
    return same;
  }

  /// Collection Reference
  /// FirebaseFirestore.instance.collection('example')
  set query(Query? reference) {
    if (loading) return;
    final totalToFetch = limit * page;
    if (isSameQuery(reference)) return;
    baseQuery = reference;
    _streamSubscription?.cancel();
    super.clear(notify: true);
  }

  /// Get Collection Reference
  Query? get query => baseQuery?.limit(limit * page);

  /// Firestore Document Stream Reference
  StreamSubscription<QuerySnapshot<Object?>>? _streamSubscription;

  /// Make call and listen for changes
  @override
  Future<dynamic> listen() async {
    if (loading) return data;
    if (initialized) return data;
    loading = true;
    await _streamSubscription?.cancel();
    if (query == null) {
      loading = false;
      data = null;
      return data;
    }
    initialized = true;
    try {
      _streamSubscription = query!.snapshots().listen(
        (snapshot) {
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
        },
        onError: (e) {
          super.clear(notify: true);
          error = e?.toString();
          loading = false;
        },
      );
    } catch (e) {
      super.clear(notify: true);
      error = e.toString();
    } finally {
      loading = false;
    }
    return data;
  }

  /// On page change
  @override
  void onPageChange(int newPage) async {
    await _streamSubscription?.cancel();
  }

  @override
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async {
    /// Check if the query is the same as the previous one to avoid unnecessary calls
    isSameBaseQuery(baseQuery);
    if (loading) return data;
    if (initialized) return data;
    await _streamSubscription?.cancel();
    if (query == null) {
      super.clear(notify: false);
      return data;
    }
    if (_streamSubscription != null) return listen();
    initialized = true;
    loading = true;
    try {
      final snapshot = await query!.get();
      // Default totalCount depending on the page
      totalCount = snapshot.size;
      if (totalCount > 0) {
        List<Map<String, dynamic>> items = [];
        for (var doc in snapshot.docs) {
          final item = doc;
          items.add({...item.data() as Map<String, dynamic>, 'id': item.id});
        }
        data = items;
      } else {
        data = [];
      }
    } catch (e) {
      super.clear(notify: false);
      data = null;
      error = e.toString();
    } finally {
      loading = false;
    }
    return data;
  }

  /// Clear data
  @override
  void clear({bool notify = false}) {
    super.clear(notify: notify);
    baseQuery = null;
  }
}
