import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

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
    if (streamSubscription != null) {
      try {
        await streamSubscription!.cancel();
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
    streamSubscription?.cancel();
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
    await streamSubscription?.cancel();
    super.clear(notify: false);
    if (baseRef == null) {
      super.notifyListeners();
      return data;
    }
    initialized = true;
    loading = true;
    data = null;
    try {
      streamSubscription = baseRef!.snapshots().listen(
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
    await streamSubscription?.cancel();
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
  ///
  /// Typed as [StreamSubscription] rather than the narrower Firestore type so
  /// subclasses and test helpers can assign any compatible subscription without
  /// importing cloud_firestore.
  @protected
  StreamSubscription<dynamic>? streamSubscription;

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
    super.clear(notify: notify);
  }

  /// Cancels the active snapshot subscription and releases shared resources.
  ///
  /// Without this override the Firestore snapshot listener started by [listen]
  /// keeps firing after the widget is gone. Each snapshot calls
  /// [notifyListeners] on a disposed [ChangeNotifier], which Flutter treats as
  /// a programming error.
  @override
  void dispose() {
    streamSubscription?.cancel();
    streamSubscription = null;
    super.dispose();
  }

  /// Applies a local, unsaved change to a single field.
  ///
  /// The change is written **directly to [data]** and is immediately visible to
  /// listeners. Because the write goes to [data], **it is not revertible**:
  /// calling [revert] after [editField] will discard the [copy] draft but leave
  /// [data] — and therefore the `editField` change — in place.
  ///
  /// **Preferred approach:** stage changes on the [copy] draft instead. Assign
  /// `copy` a modified copy of [serialized], mutate its fields, and call [save]
  /// when the user confirms. This leaves [data] untouched until the write
  /// succeeds, so [revert] can discard the draft without side effects.
  ///
  /// This method is retained for backward compatibility. New code should prefer
  /// the [copy]-based workflow described above.
  void editField(String key, dynamic value) {
    final current = data;
    final updated = current is Map
        ? Map<String, dynamic>.from(current)
        : <String, dynamic>{};
    updated[key] = value;
    data = updated;
  }

  /// Discards the in-progress [copy] draft and leaves edit mode.
  ///
  /// This call **does not restore [data]**. Because the recommended editing
  /// workflow stages changes on [copy] rather than writing them to [data]
  /// directly, [data] is unchanged during a typical edit session and there is
  /// nothing to restore. The draft is discarded by invalidating [copy]; the
  /// next read returns a fresh instance from the current [data].
  ///
  /// **Important:** if [editField] was called during the edit session, those
  /// changes are in [data] and will **not** be rolled back by this call.
  /// [editField] writes directly to [data]; see its documentation for the
  /// recommended alternative.
  ///
  /// The unconditional [notifyListeners] call guarantees that listeners observe
  /// the edit-mode exit even when no draft mutations were ever made, which
  /// would otherwise produce no notification and leave the view stuck in edit
  /// mode after a cancel.
  void revert() {
    exitEdit(); // _edit = false, invalidateCopy() — no extra notification
    notifyListeners();
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
    exitEdit(); // _edit = false, invalidateCopy() — no extra notification
    notifyListeners();
  }
}
