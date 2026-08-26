import 'package:fabric_flutter/state/state_users.dart';

/// [StateUsers] whose batched read is served from memory instead of Firestore.
///
/// [StateUsers.fetchUsersById] is the injection seam for the only network call
/// in the class, so overriding it lets a test exercise the real queue,
/// chunking, caching, and notification logic while staying hermetic. Without
/// this the batch timer would reach a real `cloud_firestore` plugin that has no
/// platform channel bound under `flutter test`.
class FakeStateUsers extends StateUsers {
  /// Creates a fake that resolves [documents] and records every request.
  FakeStateUsers([Map<String, Map<String, dynamic>>? documents])
    : documents = documents ?? const {};

  /// Holds the payload returned for each requested identifier.
  ///
  /// Identifiers absent from this map resolve to nothing, which mirrors a
  /// document that does not exist.
  final Map<String, Map<String, dynamic>> documents;

  /// Captures every chunk handed to the fetch so tests can assert batching.
  final List<List<String>> requests = [];

  @override
  Future<Map<String, Map<String, dynamic>>> fetchUsersById(
    List<String> uids,
  ) async {
    requests.add(List<String>.of(uids));
    return {
      for (final uid in uids)
        if (documents.containsKey(uid)) uid: documents[uid]!,
    };
  }
}
