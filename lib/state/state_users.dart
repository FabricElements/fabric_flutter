import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../helper/log_color.dart';
import '../helper/serialization_error.dart';
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

  /// Caches the last serialized result together with the [data] reference it
  /// was built from.
  ///
  /// [serialized] deserializes and sorts the entire user list, and it is read
  /// repeatedly per update (once inside [notifyListeners] plus once per widget
  /// build). Because [data] is replaced by a new object on every fetch, an
  /// identity check lets repeated reads of the same data reuse the previous
  /// result instead of redoing N `fromJson` calls and a full sort each time.
  List<UserData>? _serializedCache;

  /// Holds the [data] reference that produced [_serializedCache].
  Object? _serializedCacheToken;

  /// Returns the current query results as sorted [UserData] objects.
  ///
  /// Sorting by [UserData.name] keeps user pickers stable even when Firestore
  /// returns documents in a different order. The result is memoized against the
  /// current [data] reference so repeated reads within the same update are free.
  @override
  List<UserData> get serialized {
    final currentData = data;
    if (currentData == null) return [];
    if (_serializedCache != null &&
        identical(_serializedCacheToken, currentData)) {
      return _serializedCache!;
    }
    try {
      List<UserData> items = (currentData as List<dynamic>)
          .map((value) => UserData.fromJson(value))
          .toList();
      items.sort((a, b) => a.name.compareTo(b.name));
      _serializedCache = items;
      _serializedCacheToken = currentData;
      return items;
    } catch (e) {
      error = serializationError(e);
      return [];
    }
  }

  /// Caches users from both collection queries and individual [getUser] calls.
  final Map<String, UserData> _usersMap = {};

  /// Returns the combined user cache keyed by user identifier.
  Map<String, UserData> get usersMap => _usersMap;

  /// Returns a user for [uid], fetching it lazily if needed.
  ///
  /// A temporary `Unknown` user is inserted immediately so callers can render a
  /// placeholder while the Firestore lookup completes. Once the request
  /// finishes, the cache is updated and listeners are notified.
  UserData getUser(String uid) {
    if (_usersMap.containsKey(uid)) {
      return _usersMap[uid]!;
    }
    _usersMap.addAll({
      uid: UserData.fromJson({'id': uid, 'name': 'Unknown'}),
    });
    final userDocRef = db.collection('user').doc(uid);
    userDocRef
        .get()
        .then((snapshot) async {
          if (snapshot.exists) {
            Map<String, dynamic> itemData =
                snapshot.data() as Map<String, dynamic>;
            itemData.addAll({'id': uid});
            _usersMap.addAll({uid: UserData.fromJson(itemData)});
            await Future.delayed(const Duration(milliseconds: 500));
            notifyListeners();
          }
        })
        .onError((error, stackTrace) {
          debugPrint(LogColor.error('StateUsers.getUser: ${error.toString()}'));
        });
    return _usersMap[uid]!;
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
