import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../helper/drop_file_format.dart';

/// Wires browser file drag-and-drop into a Flutter drop zone on the web.
///
/// The region attaches `dragenter`/`dragover`/`dragleave`/`drop` listeners to the
/// document and calls `preventDefault` on each so the browser never navigates to
/// a dropped file. Pointer coordinates are hit-tested against the region's
/// [RenderBox] rect to decide whether a drag is hovering the zone, which avoids
/// the complexity of platform views and works under both CanvasKit and skwasm.
/// This approach assumes the Flutter view fills the page, which is the case for
/// the apps that consume the package; an inset view would need the host element
/// offset subtracted from the pointer coordinates.
class DropRegion extends StatefulWidget {
  /// Creates a web drop region that renders [child] and reports drops.
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

  /// Creates the state that manages the document drag listeners.
  @override
  State<DropRegion> createState() => _DropRegionState();
}

/// Manages document-level drag listeners and hover hit-testing for [DropRegion].
class _DropRegionState extends State<DropRegion> {
  /// Identifies the child render object used for pointer hit-testing.
  final GlobalKey _regionKey = GlobalKey();

  /// Tracks whether a drag is currently reported as hovering the region.
  bool _hovering = false;

  /// Retained `dragenter`/`dragover` listener so it can be removed on dispose.
  ///
  /// Both events run the identical hover check, so they share one handler and
  /// one retained reference.
  late final JSFunction _moveJs = _onDragMove.toJS;

  /// Retained `dragleave` listener so it can be removed on dispose.
  late final JSFunction _leaveJs = _onDragLeave.toJS;

  /// Retained `drop` listener so it can be removed on dispose.
  late final JSFunction _dropJs = _onDrop.toJS;

  /// Registers the document drag listeners once the widget mounts.
  @override
  void initState() {
    super.initState();
    web.document.addEventListener('dragenter', _moveJs);
    web.document.addEventListener('dragover', _moveJs);
    web.document.addEventListener('dragleave', _leaveJs);
    web.document.addEventListener('drop', _dropJs);
  }

  /// Removes the document drag listeners when the widget is disposed.
  @override
  void dispose() {
    web.document.removeEventListener('dragenter', _moveJs);
    web.document.removeEventListener('dragover', _moveJs);
    web.document.removeEventListener('dragleave', _leaveJs);
    web.document.removeEventListener('drop', _dropJs);
    super.dispose();
  }

  /// Returns whether viewport coordinates fall inside the region rect.
  ///
  /// Flutter's global logical coordinates align with the browser's client
  /// coordinates when the view fills the page, so the pointer position is tested
  /// directly against the child's [RenderBox] bounds.
  bool _isInside(double clientX, double clientY) {
    final box = _regionKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final origin = box.localToGlobal(Offset.zero);
    return (origin & box.size).contains(Offset(clientX, clientY));
  }

  /// Updates and reports the hover state when it changes.
  void _setHovering(bool value) {
    if (_hovering == value) return;
    _hovering = value;
    widget.onDraggingChanged?.call(value);
  }

  /// Marks the drag as a copy operation and blocks the default navigation.
  void _allowDrag(web.DragEvent event) {
    event.preventDefault();
    event.dataTransfer?.dropEffect = 'copy';
  }

  /// Handles a drag entering or moving over the document and refreshes hover.
  ///
  /// `dragenter` and `dragover` perform the identical work — allow the copy
  /// operation and re-run the hit-test — so they share this handler.
  void _onDragMove(web.Event event) {
    final drag = event as web.DragEvent;
    _allowDrag(drag);
    _setHovering(_isInside(drag.clientX.toDouble(), drag.clientY.toDouble()));
  }

  /// Clears the hover state only when the drag leaves the window entirely.
  ///
  /// `dragleave` also fires while the pointer moves between nested elements, so
  /// clearing unconditionally would flicker the hover state. A `null`
  /// `relatedTarget` distinguishes leaving the whole document from an internal
  /// transition, and the continuous `dragover` stream keeps the state fresh
  /// otherwise.
  void _onDragLeave(web.Event event) {
    final drag = event as web.DragEvent;
    drag.preventDefault();
    if (drag.relatedTarget == null) _setHovering(false);
  }

  /// Reads dropped files and forwards those that land inside the region.
  void _onDrop(web.Event event) {
    final drag = event as web.DragEvent;
    drag.preventDefault();
    final inside = _isInside(drag.clientX.toDouble(), drag.clientY.toDouble());
    _setHovering(false);
    final transfer = drag.dataTransfer;
    if (!inside || transfer == null) return;
    unawaited(_deliver(transfer.files));
  }

  /// Reads every file in [files] and delivers the readable ones.
  Future<void> _deliver(web.FileList files) async {
    final futures = <Future<DropZoneFile?>>[];
    for (var i = 0; i < files.length; i++) {
      final file = files.item(i);
      if (file != null) futures.add(_readFile(file));
    }
    final results = await Future.wait(futures);
    final dropped = results.whereType<DropZoneFile>().toList();
    if (dropped.isNotEmpty) await widget.onDrop(dropped);
  }

  /// Reads a single [file] into a [DropZoneFile], or `null` when it fails.
  ///
  /// The bytes are read through `File.arrayBuffer`, which resolves to raw binary
  /// data without the base64 detour and without the fragile completer-and-timeout
  /// pattern the previous reader API required.
  Future<DropZoneFile?> _readFile(web.File file) async {
    try {
      final buffer = await file.arrayBuffer().toDart;
      final bytes = buffer.toDart.asUint8List();
      final type = file.type;
      return DropZoneFile(
        bytes: bytes,
        name: file.name,
        size: file.size,
        mimeType: type.isEmpty ? null : type,
      );
    } catch (e) {
      debugPrint('Error reading dropped file: $e');
      return null;
    }
  }

  /// Builds the hit-testable wrapper around [DropRegion.child].
  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _regionKey, child: widget.child);
  }
}
