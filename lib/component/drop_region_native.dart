import 'dart:convert';
import 'dart:typed_data';

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
    this.fallbackName = 'file',
  });

  /// The content displayed inside, and hit-tested as, the drop region.
  final Widget child;

  /// Base name given to a file rebuilt from a string item that carries no name.
  ///
  /// The iOS drop path delivers a dragged `.csv` or `.vcf` as text with no file
  /// name, so the region has to invent one. Set this to the noun that describes
  /// what the surrounding surface accepts — `contacts`, `media` — so the staged
  /// file reads meaningfully in the UI; the default is the generic `file`. The
  /// name is combined with the drop date and the detected extension, and real
  /// file names are never touched.
  final String fallbackName;

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
    _stringFileNames.clear();
    await _deliver(details.items);
  }

  /// Reads every file in [items] and delivers the readable ones.
  ///
  /// Dropped plain strings and directories are skipped or marked unreadable.
  /// The web implementation gets a file list that cannot contain them, whereas
  /// the platform hands over every kind of item the drag source offered, and a
  /// string would otherwise be read as if it were a file.
  ///
  /// A string item can nevertheless carry a real file: on iOS a dragged file
  /// whose UTI conforms to `public.text` (a `.csv` or `.vcf`) is classified as a
  /// string by the platform plugin, which delivers the file's contents as text
  /// under a `text/plain` MIME type, with no name. Such an item is recognized
  /// through its MIME type — `text/csv`, `text/vcard`, and variants are
  /// file-like by declaration — or, for the iOS `text/plain` case, by sniffing
  /// the content, and rebuilt into a [DropZoneFile] from the UTF-8 bytes so it
  /// is not lost as an unreadable drop. Genuine text snippets are still
  /// skipped.
  Future<void> _deliver(List<DropItem> items) async {
    final futures = <Future<DropZoneFile>>[];
    for (final item in items) {
      if (item is DropStringItem) {
        final stringFile = _stringItemAsFile(item);
        if (stringFile != null) futures.add(Future.value(stringFile));
        continue;
      }
      if (item is DropItemDirectory || item.isDirectory) {
        futures.add(Future.value(DropZoneFile.unreadable(item.name)));
        continue;
      }
      futures.add(_readFile(item));
    }
    if (futures.isEmpty) {
      await widget.onDrop([DropZoneFile.unreadable('')]);
      return;
    }
    await widget.onDrop(await Future.wait(futures));
  }

  /// Rebuilds a string item that actually carries a file into a
  /// [DropZoneFile], or returns `null` for a genuine plain-text drop.
  ///
  /// The name and canonical MIME type are derived from the recognized format
  /// because the iOS drop path delivers the text without a name and reports
  /// only `text/plain`. The name is built from [DropRegion.fallbackName], the
  /// drop date and the detected extension; a counter keeps names unique when a
  /// single drop carries several such files.
  DropZoneFile? _stringItemAsFile(DropStringItem item) {
    final (extension, mimeType) = _classifyStringItem(
      item.mimeType,
      item.value,
    );
    if (extension == null) return null;
    final fileName = '${widget.fallbackName}-${_today()}.$extension';
    final bytes = Uint8List.fromList(utf8.encode(item.value));
    return DropZoneFile(
      bytes: bytes,
      name:
          _stringFileNames.update(
                fileName,
                (count) => count + 1,
                ifAbsent: () => 1,
              ) ==
              1
          ? fileName
          : '${_stripExtension(fileName)}-${_stringFileNames[fileName]}.${_extensionOf(fileName)}',
      size: bytes.length,
      mimeType: mimeType,
    );
  }

  /// Names assigned to files rebuilt from string items during the current
  /// drop, used to keep multi-file drops unique.
  final Map<String, int> _stringFileNames = <String, int>{};

  /// Maps a string item to its file extension and canonical MIME type, or
  /// `null` when the item is a plain text snippet rather than a file.
  ///
  /// File-like MIME types are recognized by declaration. A `text/plain` or
  /// untyped item is sniffed instead: on iOS that is the only form in which a
  /// dragged `.csv` or `.vcf` arrives. A value beginning with `BEGIN:VCARD` is
  /// a vCard, and a value whose records are two or more non-empty lines that
  /// each carry the same positive number of commas is a csv. Anything else —
  /// including single-line notes and prose — is treated as plain text.
  ///
  /// Only the extension is returned; the name is built by the caller so it can
  /// carry the caller's own fallback noun.
  static (String?, String?) _classifyStringItem(String mimeType, String value) {
    switch (mimeType.toLowerCase()) {
      case 'text/csv':
      case 'text/comma-separated-values':
      case 'application/csv':
        return ('csv', 'text/csv');
      case 'text/vcard':
      case 'text/x-vcard':
        return ('vcf', 'text/vcard');
      case 'text/plain':
      case '':
        break;
      default:
        return (null, null);
    }
    if (value.trimLeft().toUpperCase().startsWith('BEGIN:VCARD')) {
      return ('vcf', 'text/vcard');
    }
    if (_looksLikeCsv(value)) return ('csv', 'text/csv');
    return (null, null);
  }

  /// The current local date as `yyyy-MM-dd`.
  ///
  /// A rebuilt file name carries the drop date so repeated imports of the same
  /// kind of content do not collapse onto one indistinguishable name.
  static String _today() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  /// Whether [value] is shaped like a csv document.
  ///
  /// Every non-empty line must contain the same positive number of commas and
  /// there must be at least two records, so single-line prose or notes that
  /// merely contain commas do not qualify.
  static bool _looksLikeCsv(String value) {
    final lines = value
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return false;
    final fieldCount = ','.allMatches(lines.first).length + 1;
    if (fieldCount < 2) return false;
    return lines.every((line) => ','.allMatches(line).length + 1 == fieldCount);
  }

  /// Removes the extension from [fileName], leaving the base name.
  static String _stripExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? fileName : fileName.substring(0, dot);
  }

  /// Returns the extension of [fileName], or an empty string when it has none.
  static String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1);
  }

  /// Reads a single [item] into a [DropZoneFile], or an unreadable placeholder when it fails.
  ///
  /// The bytes are read through the item, which serves in-memory bytes directly
  /// and otherwise asks the platform for the file contents. The size is taken
  /// from those same bytes rather than from a separate length query, so the two
  /// cannot disagree and only one read is needed.
  Future<DropZoneFile> _readFile(DropItem item) async {
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
      return DropZoneFile.unreadable(item.name);
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
