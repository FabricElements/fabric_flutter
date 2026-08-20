import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../serialized/agent_element_snapshot.dart';
import '../log_color.dart';
import 'agent_element.dart';

/// Tracks every interactive widget an agent can currently read or drive.
///
/// Widgets register themselves through `AgentElement` when they declare an
/// `automationKey` and unregister when they are disposed, so the index always
/// mirrors what is on screen. Registration is passive: it never rebuilds the
/// widget tree, never touches the accessibility tree, and costs nothing when a
/// widget has no `automationKey`.
class AgentElementIndex {
  /// Creates an empty index.
  ///
  /// Prefer [instance] in application code. A local index is useful in tests
  /// that need full isolation.
  AgentElementIndex();

  /// Provides the shared index used by the widgets and the bridge.
  ///
  /// A singleton is used deliberately so transports running outside the widget
  /// tree can reach the index without a [BuildContext].
  static final AgentElementIndex instance = AgentElementIndex();

  /// Maps each element identifier to its registered handle.
  final Map<String, AgentElementHandle> _elements =
      <String, AgentElementHandle>{};

  /// Broadcasts a signal whenever the set of indexed elements changes.
  final StreamController<void> _controller = StreamController<void>.broadcast();

  /// Guards against scheduling more than one change notification per frame.
  bool _notificationScheduled = false;

  /// Emits an event whenever elements are registered or unregistered.
  ///
  /// Events are delivered asynchronously so registration during a build phase
  /// can never trigger a reentrant notification.
  Stream<void> get changes => _controller.stream;

  /// Returns every registered identifier in registration order.
  List<String> get ids => List.unmodifiable(_elements.keys);

  /// Reports how many elements are currently indexed.
  int get length => _elements.length;

  /// Reports whether an element with [id] is currently indexed.
  bool contains(String id) => _elements.containsKey(id);

  /// Returns the handle registered under [id], or `null` when absent.
  AgentElementHandle? handle(String id) => _elements[id];

  /// Adds [handle] to the index.
  ///
  /// When another handle already uses the same identifier the new handle wins,
  /// matching the behavior of a duplicated `automationKey` in the accessibility
  /// tree. A debug-only warning is emitted so the duplicate can be fixed.
  void register(AgentElementHandle handle) {
    if (handle.id.isEmpty) return;
    if (kDebugMode && _elements.containsKey(handle.id)) {
      debugPrint(
        LogColor.warning(
          'AgentElementIndex: duplicate automationKey "${handle.id}"; '
          'the most recently mounted element wins.',
        ),
      );
    }
    _elements[handle.id] = handle;
    _scheduleNotification();
  }

  /// Removes [handle] from the index.
  ///
  /// The removal is identity-checked so a disposed widget cannot evict a newer
  /// element that reused the same identifier. Returns `true` when the handle
  /// was removed.
  bool unregister(AgentElementHandle handle) {
    if (!identical(_elements[handle.id], handle)) return false;
    _elements.remove(handle.id);
    _scheduleNotification();
    return true;
  }

  /// Removes the element registered under [id], whichever handle owns it.
  ///
  /// Returns `true` when an element was removed.
  bool unregisterId(String id) {
    final removed = _elements.remove(id) != null;
    if (removed) _scheduleNotification();
    return removed;
  }

  /// Returns a snapshot of every indexed element.
  List<AgentElementSnapshot> snapshot() => _elements.values
      .map((element) => element.snapshot())
      .toList(growable: false);

  /// Returns a snapshot of the element registered under [id].
  ///
  /// Returns `null` when no element matches.
  AgentElementSnapshot? snapshotOf(String id) => _elements[id]?.snapshot();

  /// Removes every indexed element.
  ///
  /// Intended for tests and for hosts that tear the widget tree down manually.
  void reset() {
    if (_elements.isEmpty) return;
    _elements.clear();
    _scheduleNotification();
  }

  /// Queues a single change notification for the next microtask.
  void _scheduleNotification() {
    if (_notificationScheduled || _controller.isClosed) return;
    _notificationScheduled = true;
    scheduleMicrotask(() {
      _notificationScheduled = false;
      if (!_controller.isClosed) _controller.add(null);
    });
  }
}
