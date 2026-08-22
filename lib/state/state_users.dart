import 'dart:async';
import 'dart:math' show min;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../helper/log_color.dart';
import '../helper/serialization_error.dart';
import '../helper/user_query.dart';
import '../serialized/user_data.dart';
import '../variables.dart';
import 'state_collection.dart';

/// Provides the shared Firestore instance used by [StateUsers].
final db = FirebaseFirestore.instance;

/// Manages cached and queried user records.
///
/// This collection state exposes users fetched through the active Firestore
/// query as well as ad-hoc lookups performed through [getUser]. Widgets can
/// listen to the notifier to rebuild whenever either source updates the shared
/// user cache.
class StateUsers extends StateCollection {
  /// Uses a larger default page size because user lists are commonly needed for
  /// lookups and participant pickers.
  @override
  int get limitDefault => 200;

  /// Caches the last serialized result together with the [data] reference it
  /// was built from.
  ///
  /// [serialized] deserializes and sorts the entire user list, and it is read
  /// repeatedly per update (once inside [notifyListeners] plus once per widget
  /// build). Because [data] is replaced by a new object on every fetch, an
  /// identity check lets repeated reads of the same data reuse the previous
  /// result instead of redoing N `fromJson` calls and a full sort each time.
  ///
  /// Returns the current query results as sorted [UserData] objects.
  ///
  /// Sorting by [UserData.name] keeps user pickers stable even when Firestore
  /// returns documents in a different order. The result is memoized against the
  /// current [data] reference so repeated reads within the same update are free.
  @override
  List<UserData> get serialized {
    final currentData = data;
    if (currentData == null) return [];
    try {
      return cachedSerialize(currentData, () {
        List<UserData> items = (currentData as List<dynamic>)
            .map((value) => UserData.fromJson(value))
            .toList();
        items.sort((a, b) => a.name.compareTo(b.name));
        return items;
      });
    } catch (e) {
      error = serializationError(e);
      return [];
    }
  }

  /// Caches users from both collection queries and individual [getUser] calls.
  final Map<String, UserData> _usersMap = {};

  /// Returns the combined user cache keyed by user identifier.
  Map<String, UserData> get usersMap => _usersMap;

  /// Limits how many identifiers a single batched lookup resolves at once.
  ///
  /// The value dates from the Firestore `whereIn` cap of 30 values. Lookups are
  /// now issued as individual document `get` operations, so the constant no
  /// longer satisfies a query restriction; it bounds how many reads are in
  /// flight concurrently. The name is retained because it is part of the public
  /// API.
  static const int whereInLimit = 30;

  /// Holds identifiers that were requested but not yet sent to Firestore.
  final Set<String> _pendingUids = {};

  /// Holds identifiers that belong to a batch currently awaiting a response.
  ///
  /// Combined with [_pendingUids] this guarantees that requesting the same
  /// identifier repeatedly never produces more than one document read.
  final Set<String> _inFlightUids = {};

  /// Coalesces requests made during the same frame into a single batch.
  Timer? _batchTimer;

  /// Returns the cached [UserData] for [uid] without triggering a fetch.
  ///
  /// Widgets should call this from `build` and call [getUser] or
  /// [prefetchUsers] from `initState` so that rendering never starts network
  /// work. Returns `null` when the identifier has never been requested.
  UserData? cachedUser(String uid) => _usersMap[uid];

  /// Requests [uids] in a single batched Firestore read.
  ///
  /// Identifiers that are already cached, pending, or in flight are skipped, so
  /// this is safe to call repeatedly. Prefer this over calling [getUser] in a
  /// loop when a list of users is known up front.
  void prefetchUsers(Iterable<String> uids) {
    bool scheduled = false;
    for (final uid in uids) {
      if (_enqueueUser(uid)) scheduled = true;
    }
    if (scheduled) _scheduleBatch();
  }

  /// Returns a user for [uid], fetching it lazily if needed.
  ///
  /// A temporary `Unknown` user is inserted immediately so callers can render a
  /// placeholder while the Firestore lookup completes. The identifier is queued
  /// rather than fetched on its own: every identifier requested during the same
  /// frame is resolved with chunked `whereIn` queries and produces a single
  /// [notifyListeners] call once the whole batch settles. That replaces the
  /// previous behavior of one document read plus one notification per user.
  UserData getUser(String uid) {
    final cached = _usersMap[uid];
    if (cached != null) return cached;
    final placeholder = UserData.fromJson({'id': uid, 'name': 'Unknown'});
    _usersMap[uid] = placeholder;
    if (_enqueueUser(uid)) _scheduleBatch();
    return placeholder;
  }

  /// Adds [uid] to the pending batch and reports whether a flush is required.
  ///
  /// Returns `false` when the identifier is already queued or already being
  /// fetched, which is what keeps duplicate requests from producing duplicate
  /// reads.
  bool _enqueueUser(String uid) {
    if (uid.isEmpty) return false;
    if (_inFlightUids.contains(uid)) return false;
    return _pendingUids.add(uid);
  }

  /// Defers the flush so requests issued during one frame share a batch.
  ///
  /// Scheduling is skipped under [kIsTest] so widget tests never leave a
  /// pending timer behind. Tests drive the queue with [flushPendingUsers].
  void _scheduleBatch() {
    if (kIsTest || _batchTimer != null) return;
    _batchTimer = Timer(Duration.zero, _flushPendingUsers);
  }

  /// Splits [uids] into chunks that bound concurrent document reads.
  @visibleForTesting
  static List<List<String>> chunkUids(
    List<String> uids, {
    int size = whereInLimit,
  }) {
    assert(size > 0, 'size must be greater than zero');
    final chunks = <List<String>>[];
    for (int i = 0; i < uids.length; i += size) {
      chunks.add(uids.sublist(i, min(i + size, uids.length)));
    }
    return chunks;
  }

  /// Reads the documents for [uids] and returns their raw payloads by id.
  ///
  /// Each identifier is fetched with `doc(uid).get()` rather than through a
  /// single `whereIn` filter on [FieldPath.documentId]. Both forms bill one read
  /// per returned document, but a `whereIn` filter is a Firestore **`list`**
  /// operation while a document fetch is a **`get`**. Splitting them lets a
  /// consuming project keep `allow get` open for the users a caller may resolve
  /// while denying `allow list` on the collection outright, which is impossible
  /// as long as the client issues a collection query. Reads run concurrently, so
  /// a batch still resolves in roughly one round trip.
  ///
  /// Documents that do not exist are omitted, matching the previous behavior of
  /// a `whereIn` query, which returned only the identifiers it found.
  ///
  /// Returns an empty map under [kIsTest] so tests never open a real Firestore
  /// connection. Override it in tests to supply canned documents.
  @protected
  @visibleForTesting
  Future<Map<String, Map<String, dynamic>>> fetchUsersById(
    List<String> uids,
  ) async {
    if (kIsTest || uids.isEmpty) return {};
    final collection = UserQuery.collection();
    final snapshots = await Future.wait(
      uids.map((uid) => collection.doc(uid).get()),
    );
    return {
      for (final doc in snapshots)
        if (doc.exists) doc.id: doc.data() ?? <String, dynamic>{},
    };
  }

  /// Resolves every queued identifier and notifies listeners exactly once.
  @visibleForTesting
  Future<void> flushPendingUsers() async {
    _batchTimer?.cancel();
    _batchTimer = null;
    if (_pendingUids.isEmpty) return;
    final uids = _pendingUids.toList(growable: false);
    _pendingUids.clear();
    _inFlightUids.addAll(uids);
    bool changed = false;
    try {
      final results = await Future.wait(chunkUids(uids).map(fetchUsersById));
      for (final documents in results) {
        documents.forEach((id, itemData) {
          _usersMap[id] = UserData.fromJson({...itemData, 'id': id});
          changed = true;
        });
      }
    } catch (e) {
      debugPrint(LogColor.error('StateUsers.getUser: ${e.toString()}'));
    } finally {
      _inFlightUids.removeAll(uids);
    }
    if (changed) notifyListeners();
  }

  /// Runs the queued batch, ignoring errors already reported by the flush.
  void _flushPendingUsers() {
    flushPendingUsers();
  }

  /// Cancels the pending batch timer before the notifier is torn down.
  @override
  void dispose() {
    _batchTimer?.cancel();
    _batchTimer = null;
    super.dispose();
  }

  /// Returns the cached users as a list.
  List<UserData> get users => _usersMap.values.toList();

  /// Merges freshly serialized query results into the user cache before
  /// notifying listeners.
  @override
  void notifyListeners() {
    /// Add users to the _usersMap variable
    for (UserData user in serialized) {
      _usersMap[user.id] = user;
    }
    super.notifyListeners();
  }
}
