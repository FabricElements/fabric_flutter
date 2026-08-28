import 'dart:async';
import 'dart:math' show min;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../helper/log_color.dart';
import '../helper/serialization_error.dart';
import '../helper/user_query.dart';
import '../serialized/user_data.dart';
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

  /// Tracks whether a deserialization error occurred during the last [serialized] read.
  ///
  /// This flag complements the [error] property, which uses dedup logic to avoid
  /// notifying listeners twice for the same error message. [hadSerializationError]
  /// is not deduplicated, so consumers can reliably detect every deserialization
  /// failure, including repeated failures on the same data. The flag is reset at
  /// the start of each [serialized] read and reflects whether that specific read failed.
  bool _hadSerializationError = false;

  /// Returns whether a deserialization error occurred during the last [serialized] read.
  bool get hadSerializationError => _hadSerializationError;

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
      _hadSerializationError = false;
      return cachedSerialize(currentData, () {
        List<UserData> items = (currentData as List<dynamic>)
            .map((value) => UserData.fromJson(value))
            .toList();
        items.sort((a, b) => a.name.compareTo(b.name));
        return items;
      });
    } catch (e) {
      _hadSerializationError = true;
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

  /// Tracks identifiers whose fetch attempt failed, allowing retry on subsequent
  /// [getUser] calls.
  ///
  /// When a batch fetch fails (e.g., network error), the UIDs are added here.
  /// On the next [getUser] call for a failed UID, the placeholder is discarded
  /// and the UID is re-enqueued for retry. This ensures transient network blips
  /// do not permanently cache a failed lookup.
  final Set<String> _failedUids = {};

  /// Limits how many total fetch attempts a single UID can have.
  ///
  /// Includes the initial attempt plus retries. With `maxAttempts = 3`, a UID
  /// can be attempted once initially, then retried up to 2 more times. This
  /// allows recovery from transient failures (network blips) while preventing
  /// unbounded retry loops on permanent failures (rules denials, missing users).
  static const int maxAttempts = 3;

  /// Tracks the number of fetch attempts per UID (initial + retries).
  ///
  /// Incremented in [flushPendingUsers] when a fetch fails. When a UID reaches
  /// [maxAttempts], it stops being retried and the placeholder becomes permanent.
  /// This is the authoritative mechanism for enforcement; the counter is never wiped.
  final Map<String, int> _failedAttempts = {};

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
  ///
  /// If a previous fetch for this [uid] failed, the cached placeholder is
  /// discarded and the UID is re-enqueued for retry, allowing transient network
  /// errors to be recovered. Retries are bounded: after [maxAttempts]
  /// total attempts, the placeholder becomes permanent.
  UserData getUser(String uid) {
    // If a previous fetch failed and we haven't exhausted attempts, clear the
    // failed flag and re-enqueue for retry.
    if (_failedUids.contains(uid)) {
      final attemptCount = _failedAttempts[uid] ?? 0;
      if (attemptCount < maxAttempts) {
        _failedUids.remove(uid);
        _usersMap.remove(uid);
      }
      // else: attempt limit reached, keep the placeholder and stop retrying
    }
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
  /// Tests can drive the queue deterministically with [flushPendingUsers], and
  /// supply canned documents by overriding [fetchUsersById].
  void _scheduleBatch() {
    if (_batchTimer != null) return;
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
  /// This method is the seam for tests: override it to supply canned documents
  /// so the surrounding batching, caching and notification logic runs exactly
  /// as it does in production, with only the data source replaced.
  @protected
  @visibleForTesting
  Future<Map<String, Map<String, dynamic>>> fetchUsersById(
    List<String> uids,
  ) async {
    if (uids.isEmpty) return {};
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
      // Wrap each chunk fetch so success/failure are captured as values, not thrown.
      // This preserves documents from successful chunks and only retries UIDs from
      // chunks that actually failed, rather than marking all UIDs as failed.
      final chunks = chunkUids(uids);
      final chunkResults = await Future.wait(
        chunks.map(
          (chunk) => fetchUsersById(chunk).then(
            (docs) => {'success': true, 'documents': docs, 'chunk': chunk},
            onError: (e) => {'success': false, 'chunk': chunk},
          ),
        ),
      );

      final fetchedIds = <String>{};
      final failedChunks = <List<String>>[];

      // Process results, separating successful from failed chunks.
      for (final result in chunkResults) {
        if (result['success'] == true) {
          final documents =
              result['documents'] as Map<String, Map<String, dynamic>>;
          documents.forEach((id, itemData) {
            _usersMap[id] = UserData.fromJson({...itemData, 'id': id});
            _failedAttempts.remove(id); // Clear attempt count on success
            _failedUids.remove(id);
            fetchedIds.add(id);
            changed = true;
          });
        } else {
          // Track this chunk for retry.
          failedChunks.add(result['chunk'] as List<String>);
        }
      }

      // Mark UIDs from failed chunks as failed (to be retried).
      for (final chunk in failedChunks) {
        for (final uid in chunk) {
          final attemptCount = (_failedAttempts[uid] ?? 0) + 1;
          _failedAttempts[uid] = attemptCount;
          if (attemptCount < maxAttempts) {
            _failedUids.add(uid);
          }
        }
      }

      // Mark UIDs that were not found (not in the fetched results) as genuinely
      // absent. They won't be retried.
      for (final uid in uids) {
        if (!fetchedIds.contains(uid) && !_failedUids.contains(uid)) {
          // Not a transient failure. The counter is kept for observability.
        }
      }
    } catch (e) {
      // Fallback: mark all attempted UIDs as failed so they can be retried.
      // This catches cases where Future.wait itself throws (not the futures it awaits).
      for (final uid in uids) {
        final attemptCount = (_failedAttempts[uid] ?? 0) + 1;
        _failedAttempts[uid] = attemptCount;
        if (attemptCount < maxAttempts) {
          _failedUids.add(uid);
        }
      }
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
