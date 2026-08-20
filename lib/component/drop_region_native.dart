import 'package:flutter/material.dart';

import '../helper/drop_file_format.dart';

/// Renders drop-zone content on platforms without external file drag-and-drop.
///
/// On Android and iOS the operating system does not deliver external file drops
/// to a Flutter view, so this implementation simply renders [child] and ignores
/// [onDrop] and [onDraggingChanged]. The surrounding file-picker flow still works,
/// so the drop zone remains fully functional without any throwing stubs. The web
/// build swaps in an implementation that wires real drag-and-drop events.
class DropRegion extends StatelessWidget {
  /// Creates a no-op drop region that renders [child].
  const DropRegion({
    super.key,
    required this.child,
    required this.onDrop,
    this.onDraggingChanged,
  });

  /// The content displayed inside the drop region.
  final Widget child;

  /// Receives dropped files on the web; never invoked on this platform.
  final Future<void> Function(List<DropZoneFile> files) onDrop;

  /// Reports drag-hover transitions on the web; never invoked on this platform.
  final ValueChanged<bool>? onDraggingChanged;

  /// Builds the region by returning [child] unchanged.
  @override
  Widget build(BuildContext context) => child;
}
