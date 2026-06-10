import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'state_shared.dart';

/// Manages paginated state for a Firestore query.
///
/// [StateCollection] adapts a Firestore [Query] to the lifecycle defined by
/// [StateShared]. Consumers assign [query], call [call] for one-off reads or
/// [listen] for live snapshots, and then rebuild from [data], [stream], or
/// [notifyListeners].
///
/// Pagination is always enabled for collections. The implementation resets state
/// when the underlying base query changes and scales the effective Firestore
/// limit by `[limit] * [page]` so later pages include all earlier results.
abstract class StateCollection extends StateShared {
  /// Creates a collection-backed state.
  StateCollection();

  /// Always enables pagination for collection states.
  @override
  bool get paginate => true;

  /// Always allows pagination because Firestore query pages are accumulated by
  /// increasing the fetch limit.
  @override
  bool get canPaginate => true;

  /// Stores the base Firestore query before the current page limit is applied.
  Query? baseQuery;

  /// Stops listening to the current query and clears the state.
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

  /// Returns whether [reference] matches the current paginated query.
  ///
  /// The comparison uses Firestore query parameters after applying the effective
  /// page size so rebuilds do not restart listeners unnecessarily.
  bool isSameQuery(Query? reference) {
    final totalToFetch = limit * page;
    Query? newQuery = reference?.limit(totalToFetch);
    final newReference = ({newQuery?.parameters ?? {}}).toString().hashCode;
    final oldReference = ({query?.parameters ?? {}}).toString().hashCode;
    return oldReference == newReference;
  }

  /// Returns whether [reference] matches the current base query.
  ///
  /// When the query changes, shared state is cleared so results from the old
  /// collection do not survive into the new query context.
  bool isSameBaseQuery(Query? reference) {
    final newReference = ({reference?.parameters ?? {}}).toString().hashCode;
    final oldReference = ({baseQuery?.parameters ?? {}}).toString().hashCode;
    bool same = oldReference == newReference;
    if (!same) {
      super.clear(notify: !initialized);
    }
    return same;
  }

  /// Assigns the base Firestore query.
  ///
  /// FirebaseFirestore.instance.collection('example')
  ///
  /// Setting a new query cancels any active listener and clears the current data
  /// so future reads start from a clean slate.
  set query(Query? reference) {
    if (loading) return;
    final totalToFetch = limit * page;
    if (isSameQuery(reference)) return;
    baseQuery = reference;
    _streamSubscription?.cancel();
    super.clear(notify: true);
  }

  /// Returns the active query with the effective page limit applied.
  Query? get query => baseQuery?.limit(limit * page);

  /// Holds the active Firestore query snapshot subscription.
  StreamSubscription<QuerySnapshot<Object?>>? _streamSubscription;

  /// Starts listening to live updates for the current [query].
  ///
  /// Call this when the UI should stay synchronized with Firestore. Each update
  /// replaces [data] with a fresh list of serialized documents containing their
  /// Firestore `id` fields.
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

  /// Cancels the active query subscription when pagination changes.
  ///
  /// Collection pages are materialized by rebuilding the query with a larger
  /// limit, so the old listener must be torn down first.
  @override
  void onPageChange(int newPage) async {
    await _streamSubscription?.cancel();
  }

  /// Fetches the current query once without keeping a live listener attached.
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

  /// Clears the base query and resets shared collection state.
  @override
  void clear({bool notify = false}) {
    super.clear(notify: notify);
    baseQuery = null;
  }
}
