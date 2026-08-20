import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import 'state_shared.dart';

/// Manages state for a single Firestore document.
///
/// This base class bridges a [DocumentReference] with the shared state lifecycle
/// from [StateShared]. Consumers usually assign [ref] and then call either
/// [call] for a one-time fetch or [listen] for live snapshots. Updates propagate
/// through [data], [stream], and [notifyListeners], making it suitable for views
/// that need to rebuild when a document changes.
///
/// The implementation intentionally ignores a few server-managed fields during
/// equality checks so heartbeat-style writes do not trigger unnecessary UI
/// updates.
abstract class StateDocument extends StateShared {
  /// Creates a document-backed state.
  StateDocument();

  /// Stores the current Firestore document reference.
  DocumentReference? baseRef;

  /// Stops listening to the current document and clears the state.
  ///
  /// Pass [notify] when listeners should also receive the cleared value.
  Future<void> cancel({bool notify = false}) async {
    baseRef = null;
    if (_streamSubscription != null) {
      try {
        await _streamSubscription!.cancel();
      } catch (error) {
        //
      }
    }
    return clear(notify: notify);
  }

  /// Assigns the document reference that subsequent reads and listeners use.
  ///
  /// Reassigning the same path is ignored. Changing the reference cancels any
  /// active stream subscription and clears existing state so the next fetch does
  /// not mix data from different documents.
  ///
  /// FirebaseFirestore.instance.collection('example')
  set ref(DocumentReference? reference) {
    if (loading) return;
    final oldReference = baseRef?.path ?? '';
    final newReference = reference?.path ?? '';
    if (newReference == oldReference) return;
    _streamSubscription?.cancel();
    baseRef = reference;
    super.clear(notify: true);
  }

  /// Starts listening to live updates from [ref].
  ///
  /// Call this once during a widget lifecycle when the UI should stay in sync
  /// with Firestore changes. The listener suppresses rebuilds for changes that
  /// only affect ignored metadata keys.
  @override
  Future<dynamic> listen() async {
    if (loading) return data;
    if (initialized) return data;
    loading = true;
    await _streamSubscription?.cancel();
    super.clear(notify: false);
    if (baseRef == null) {
      super.notifyListeners();
      return data;
    }
    initialized = true;
    loading = true;
    data = null;
    try {
      _streamSubscription = baseRef!.snapshots().listen(
        (snapshot) {
          loading = false;
          if (snapshot.exists) {
            /// Compare data
            final newData = {
              ...snapshot.data() as Map<String, dynamic>,
              'id': snapshot.id,
            };
            if (privateData != null) {
              Map<String, dynamic> dataObjectMap = Map<String, dynamic>.from(
                newData,
              );
              Map<String, dynamic> privateDataMap = Map<String, dynamic>.from(
                privateData,
              );
              const keysToIgnoreFromNotification = [
                'updated',
                'created',
                'ping',
                'os',
                'backup',
                'fcm',
              ];
              // Remove keys that match with [keysToIgnoreFromNotification]
              dataObjectMap.removeWhere(
                (key, value) => keysToIgnoreFromNotification.contains(key),
              );
              privateDataMap.removeWhere(
                (key, value) => keysToIgnoreFromNotification.contains(key),
              );
              // Basic comparison
              if (dataObjectMap == privateDataMap) return;
              if (const DeepCollectionEquality().equals(
                dataObjectMap,
                privateDataMap,
              )) {
                return;
              }
            }

            /// Assign new data
            data = newData;
          } else {
            data = null;
          }
        },
        onError: (e) {
          initialized = false;
          loading = false;
          error = e?.toString();
        },
      );
    } catch (e) {
      initialized = false;
      loading = false;
      error = e.toString();
    }
    return data;
  }

  /// Fetches the current document once without maintaining a live subscription.
  @override
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async {
    if (loading) return data;
    if (initialized) return data;
    loading = true;
    await _streamSubscription?.cancel();
    super.clear(notify: false);
    if (baseRef == null) {
      data = null;
      return data;
    }
    loading = true;
    try {
      initialized = true;
      final snapshot = await baseRef!.get();
      data = {...snapshot.data() as Map<String, dynamic>, 'id': snapshot.id};
    } catch (e) {
      initialized = false;
      loading = false;
      error = e.toString();
    }
    loading = false;
    return data;
  }

  /// Returns the current Firestore document reference.
  DocumentReference? get ref => baseRef;

  /// Holds the active Firestore snapshot subscription.
  StreamSubscription<DocumentSnapshot<Object?>>? _streamSubscription;

  /// Updates fields on the current Firestore document.
  ///
  /// This requires [ref] to be non-null.
  Future<void> update(Map<String, dynamic> newData) => baseRef!.update(newData);

  /// Writes [newData] to the current Firestore document.
  ///
  /// Set [merge] to preserve unspecified fields instead of replacing the full
  /// document.
  Future<void> set(Map<String, dynamic> newData, {bool merge = false}) =>
      baseRef!.set(newData, SetOptions(merge: merge));

  /// Clears the document reference and resets shared state.
  @override
  void clear({bool notify = true}) {
    baseRef = null;
    _edit = false;
    _copy = null;
    super.clear(notify: notify);
  }

  /// Tracks whether the document is currently open for editing.
  bool _edit = false;

  /// Holds the snapshot captured when editing started.
  Map<String, dynamic>? _copy;

  /// Returns whether the document is currently open for editing.
  ///
  /// This flag is purely local UI state: it does not gate Firestore writes and
  /// it never changes on its own when a snapshot arrives. Views typically bind
  /// it to an "Edit" / "Done" toggle and read it to decide whether to render
  /// form fields or read-only content.
  bool get edit => _edit;

  /// Enters or leaves edit mode and notifies listeners.
  ///
  /// Entering edit mode captures a shallow snapshot of the current [data] into
  /// [copy] so [revert] can restore it. Leaving edit mode discards that snapshot
  /// and keeps whatever is currently in [data], which makes assigning `false`
  /// the "accept the local changes" path. Use [revert] to discard them instead.
  ///
  /// Reassigning the current value is ignored, so a rebuild that re-applies the
  /// same flag will not clobber an existing snapshot.
  set edit(bool value) {
    if (_edit == value) return;
    _edit = value;
    _copy = value ? _snapshot() : null;
    notifyListeners();
  }

  /// Returns the snapshot captured when edit mode was entered.
  ///
  /// The value is `null` outside of edit mode, or when editing started while the
  /// document had no data. The returned map is the state's own copy: mutate it
  /// only if you intend to change what [revert] restores.
  Map<String, dynamic>? get copy => _copy;

  /// Returns a defensive shallow copy of the current [data].
  ///
  /// A shallow copy is enough to undo the top-level field edits that document
  /// forms perform. Nested maps and lists are shared with [data], so subclasses
  /// that edit nested structures should replace them wholesale rather than
  /// mutating them in place.
  Map<String, dynamic>? _snapshot() {
    final current = data;
    if (current is! Map) return null;
    return Map<String, dynamic>.from(current);
  }

  /// Applies a local, unsaved change to a single field while editing.
  ///
  /// Assigning through this method — rather than mutating `data[key]` directly —
  /// is what makes the change visible: [data] compares payloads structurally, so
  /// an in-place mutation of the existing map would be indistinguishable from
  /// the previous value and would never notify listeners.
  ///
  /// The change is local only. Call [save] to persist it, or [revert] to discard
  /// it. Calling this outside of edit mode still updates [data] but leaves no
  /// snapshot to revert to.
  void editField(String key, dynamic value) {
    final current = data;
    final updated = current is Map
        ? Map<String, dynamic>.from(current)
        : <String, dynamic>{};
    updated[key] = value;
    data = updated;
  }

  /// Discards local edits and restores the snapshot taken when editing started.
  ///
  /// Leaves edit mode and notifies listeners. When no snapshot exists — because
  /// editing never started, or started on an empty document — the current [data]
  /// is left untouched and only the edit flag is cleared.
  void revert() {
    final snapshot = _copy;
    _edit = false;
    _copy = null;
    if (snapshot != null) {
      data = snapshot;
    } else {
      notifyListeners();
    }
  }

  /// Persists the current [data] to Firestore and leaves edit mode.
  ///
  /// The document `id` is stripped before writing because it is the document key
  /// rather than a stored field. Edit mode is only exited after the write
  /// succeeds, so a failed save leaves the user's changes on screen; the error is
  /// recorded through [error] and rethrown for callers that want to react to it.
  ///
  /// [merge] defaults to `true` so unspecified fields are preserved, which is the
  /// safe choice for partial document forms.
  Future<void> save({bool merge = true}) async {
    final current = data;
    if (current is! Map) return;
    final payload = Map<String, dynamic>.from(current)..remove('id');
    try {
      await set(payload, merge: merge);
    } catch (e) {
      error = e.toString();
      rethrow;
    }
    _edit = false;
    _copy = null;
    notifyListeners();
  }
}
