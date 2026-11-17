import 'package:file_drop/file_drop.dart';
import 'package:flutter/widgets.dart';

import '../helper/drop_file_format.dart';

/// Wires native platform file drag-and-drop into a Flutter drop zone.
///
/// The region wraps its child in a [DropTarget], which registers the platform
/// drag interaction (Android drag events, iOS `UIDropInteraction`) and hit-tests
/// the pointer against the child's bounds. Entering and leaving those bounds is
/// reported through [DropRegion.onDraggingChanged], and a completed drop has its
/// files read into [DropZoneFile] values before they reach [DropRegion.onDrop].
/// The platform performs the hit-testing in the render tree, so unlike the web
/// implementation there are no document listeners and no manual rect comparison.
///
/// A drop only arrives when the operating system routes an external drag to the
/// app's window. On iPadOS and in Android multi-window or desktop mode the app
/// can be a drop destination; a full-screen phone app normally cannot receive
/// one, so the region reports whatever the platform gives it and the file-picker
/// flow remains the way to stage files there.
class DropRegion extends StatefulWidget {
  /// Creates a native drop region that renders [child] and reports drops.
  const DropRegion({
    super.key,
    required this.child,
    required this.onDrop,
    this.onDraggingChanged,
  });

  /// The content displayed inside, and hit-tested as, the drop region.
  final Widget child;

  /// Receives the files read from a drop that lands inside the region.
  ///
  /// Filtering by accepted format is intentionally left to the consuming state so
  /// the region stays generic; every readable dropped file is delivered here.
  final Future<void> Function(List<DropZoneFile> files) onDrop;

  /// Reports when a drag starts or stops hovering the region.
  final ValueChanged<bool>? onDraggingChanged;

  /// Creates the state that manages hover reporting and drop reading.
  @override
  State<DropRegion> createState() => _DropRegionState();
}

/// Manages hover reporting and drop reading for [DropRegion].
class _DropRegionState extends State<DropRegion> {
  /// Tracks whether a drag is currently reported as hovering the region.
  bool _hovering = false;

  /// Updates and reports the hover state when it changes.
  void _setHovering(bool value) {
    if (_hovering == value) return;
    _hovering = value;
    widget.onDraggingChanged?.call(value);
  }

  /// Marks a drag as hovering the region once it enters the child's bounds.
  ///
  /// The platform reports entering and leaving only, with no separate move
  /// callback, because hover is a boolean rather than a position the region
  /// tracks itself.
  void _onDragEnter(DragDetails details) => _setHovering(true);

  /// Clears the hover state once the drag leaves the child's bounds.
  void _onDragLeave() => _setHovering(false);

  /// Reads dropped files and forwards the readable ones to [DropRegion.onDrop].
  ///
  /// Hover is cleared first: the platform does not guarantee a preceding leave
  /// callback, and the caller would otherwise keep its drag-active styling after
  /// the files have already landed.
  Future<void> _onDrop(DropDetails details) async {
    _setHovering(false);
    await _deliver(details.items);
  }

  /// Reads every file in [items] and delivers the readable ones.
  ///
  /// Dropped strings and directories are skipped up front. The web
  /// implementation gets a file list that cannot contain them, whereas the
  /// platform hands over every kind of item the drag source offered, and a
  /// string would otherwise be read as if it were a file.
  Future<void> _deliver(List<DropItem> items) async {
    final futures = <Future<DropZoneFile?>>[];
    for (final item in items) {
      if (item is DropStringItem) continue;
      if (item is DropItemDirectory || item.isDirectory) continue;
      futures.add(_readFile(item));
    }
    final results = await Future.wait(futures);
    final dropped = results.whereType<DropZoneFile>().toList();
    if (dropped.isNotEmpty) await widget.onDrop(dropped);
  }

  /// Reads a single [item] into a [DropZoneFile], or `null` when it fails.
  ///
  /// The bytes are read through the item, which serves in-memory bytes directly
  /// and otherwise asks the platform for the file contents. The size is taken
  /// from those same bytes rather than from a separate length query, so the two
  /// cannot disagree and only one read is needed.
  Future<DropZoneFile?> _readFile(DropItem item) async {
    try {
      final bytes = await item.readAsBytes();
      return DropZoneFile(
        bytes: bytes,
        name: item.name,
        size: bytes.length,
        mimeType: item.mimeType,
      );
    } catch (e) {
      debugPrint('Error reading dropped file: $e');
      return null;
    }
  }

  /// Builds the platform drop target around [DropRegion.child].
  ///
  /// The requested operation is a copy, matching the web implementation's
  /// `dropEffect` and the fact that a drop never moves the source file.
  @override
  Widget build(BuildContext context) {
    return DropTarget(
      operation: DropOperation.copy,
      onEnter: _onDragEnter,
      onLeave: _onDragLeave,
      onDrop: _onDrop,
      child: widget.child,
    );
  }
}
