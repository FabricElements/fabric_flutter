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
    super.clear(notify: notify);
  }
}
