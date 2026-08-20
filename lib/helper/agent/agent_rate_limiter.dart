import 'dart:collection';

/// Limits how many requests a single caller may issue inside a time window.
///
/// The bridge can drive the whole application, so an agent that loops without
/// backoff — or a stolen token — could lock the UI thread with command work.
/// A fixed number of requests per sliding window bounds that blast radius
/// without needing a dependency: each key keeps the timestamps of its recent
/// requests, entries older than [window] are dropped on every check, and the
/// number of tracked keys is bounded by [maxKeys].
class AgentRateLimiter {
  /// Creates a limiter allowing [maxRequests] per [window] for each key.
  ///
  /// [maxKeys] bounds memory by evicting the least recently seen key, which
  /// matters because the key is caller supplied when a request is anonymous.
  AgentRateLimiter({
    this.maxRequests = 60,
    this.window = const Duration(minutes: 1),
    this.maxKeys = 256,
  }) : assert(maxRequests > 0, 'maxRequests must be greater than zero'),
       assert(maxKeys > 0, 'maxKeys must be greater than zero');

  /// Bounds how many requests one key may issue inside [window].
  final int maxRequests;

  /// Sets the sliding window the request count is measured over.
  final Duration window;

  /// Bounds how many distinct keys are tracked at once.
  final int maxKeys;

  /// Stores recent request timestamps per key in least-recently-used order.
  final LinkedHashMap<String, List<DateTime>> _hits =
      LinkedHashMap<String, List<DateTime>>();

  /// Records a request for [key] and reports whether it may proceed.
  ///
  /// Returns `false` once [maxRequests] have already been recorded inside the
  /// current [window]; the rejected request is not recorded, so a caller that
  /// backs off recovers as soon as the window slides.
  bool allow(String key) {
    final now = DateTime.now();
    final cutoff = now.subtract(window);
    final hits = _hits.remove(key) ?? <DateTime>[];
    hits.removeWhere((hit) => hit.isBefore(cutoff));
    if (hits.length >= maxRequests) {
      _hits[key] = hits;
      return false;
    }
    hits.add(now);
    _hits[key] = hits;
    while (_hits.length > maxKeys) {
      _hits.remove(_hits.keys.first);
    }
    return true;
  }

  /// Returns how many requests [key] may still issue in the current window.
  int remaining(String key) {
    final cutoff = DateTime.now().subtract(window);
    final hits = _hits[key];
    if (hits == null) return maxRequests;
    final recent = hits.where((hit) => !hit.isBefore(cutoff)).length;
    final left = maxRequests - recent;
    return left < 0 ? 0 : left;
  }

  /// Forgets every recorded request, or only those for [key] when supplied.
  void reset([String? key]) {
    if (key == null) {
      _hits.clear();
      return;
    }
    _hits.remove(key);
  }
}
