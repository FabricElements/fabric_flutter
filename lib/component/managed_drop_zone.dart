import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/drop_file_format.dart';
import '../helper/format_data.dart';
import '../state/state_drop_zone.dart';
import 'alert_data.dart';
import 'drop_region.dart';
import 'live_announcer.dart';

/// Drag-and-drop upload surface that collects media before uploading it.
///
/// The widget renders a dashed drop target with a keyboard-reachable browse
/// button, lists the staged files with per-file status, and uploads them to the
/// configured [path]. Real drag-and-drop is web-only; on other platforms the
/// target still stages files through the file picker. Accepted [formats] drive
/// both drag acceptance and the picker's allowed extensions.
class ManagedDropZone extends StatefulWidget {
  /// Creates a managed drop zone for file uploads.
  ///
  /// [path] is the storage destination, [expiry] controls whether uploaded files
  /// are marked as expiring, [callback] receives the successfully uploaded media,
  /// and [formats] defines the accepted file types.
  const ManagedDropZone({
    super.key,
    required this.path,
    required this.expiry,
    required this.callback,
    required this.formats,
  });

  /// Storage path where uploaded files are written.
  final String path;

  /// Whether uploaded files should be treated as expiring assets.
  final bool expiry;

  /// Callback invoked with uploaded media items after a successful upload.
  final Function(List<MediaDataUpload> media) callback;

  /// Accepted file formats for both drag-and-drop and the file picker.
  final List<DropFileFormat> formats;

  /// Creates the state that tracks staged media and upload progress.
  @override
  State<ManagedDropZone> createState() => _ManagedDropZoneState();
}

/// State for [ManagedDropZone] that tracks staged media and upload progress.
class _ManagedDropZoneState extends State<ManagedDropZone> {
  /// Backing state object that handles drag events, picking, and uploads.
  late StateDropZone _dropState;

  /// Creates the backing state and subscribes to its change notifications.
  @override
  void initState() {
    super.initState();
    _dropState = StateDropZone(formats: widget.formats);
    _dropState.addListener(_onDropStateChanged);
  }

  /// Rebuilds the widget when the drop zone state changes.
  void _onDropStateChanged() {
    if (mounted) setState(() {});
  }

  /// Disposes the backing state so its in-flight work stops safely.
  @override
  void dispose() {
    _dropState.removeListener(_onDropStateChanged);
    // This widget creates the state, so it also has to dispose it. Without this
    // the ChangeNotifier (and any in-flight upload work) outlives the widget, and
    // the disposal guards in StateDropZone never engage.
    _dropState.dispose();
    super.dispose();
  }

  /// Returns the most appropriate icon for the staged media item [m].
  Icon _iconFor(MediaDataUpload m) {
    final contentTypePrefix = m.contentType.split('/').first;
    switch (contentTypePrefix) {
      case 'image':
        return const Icon(Icons.image);
      case 'video':
        return const Icon(Icons.movie);
      case 'audio':
        return const Icon(Icons.music_note);
      case 'application':
        return const Icon(Icons.insert_drive_file);
    }
    switch (m.extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'psd':
        return const Icon(Icons.image);
      case 'mp4':
      case 'avi':
      case 'mkv':
        return const Icon(Icons.movie);
      case 'mp3':
      case 'wav':
      case 'ogg':
        return const Icon(Icons.music_note);
      case 'pdf':
        return const Icon(Icons.picture_as_pdf);
      case 'doc':
      case 'docx':
        return const Icon(Icons.description);
      case 'xls':
      case 'xlsx':
        return const Icon(Icons.table_chart);
      case 'ppt':
      case 'pptx':
        return const Icon(Icons.slideshow);
      case 'zip':
      case 'rar':
        return const Icon(Icons.archive);
      case 'txt':
        return const Icon(Icons.text_fields);
      case 'html':
      case 'css':
      case 'js':
      case 'json':
      case 'dart':
        return const Icon(Icons.code);
      case 'apk':
        return const Icon(Icons.android);
      case 'exe':
        return const Icon(Icons.desktop_windows);
    }
    return const Icon(Icons.insert_drive_file);
  }

  /// Returns a status color for the staged media item [m].
  Color? _colorFor(MediaDataUpload m, ThemeData theme) {
    switch (m.status) {
      case MediaDataUploadStatus.pending:
        return theme.colorScheme.onSurface;
      case MediaDataUploadStatus.uploading:
        return theme.colorScheme.secondary;
      case MediaDataUploadStatus.uploaded:
        return Colors.teal;
      case MediaDataUploadStatus.failed:
        return theme.colorScheme.error;
    }
  }

  /// Builds the drop target, staged upload list, and upload actions.
  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final itemCount = _dropState.mediaList.length;

    /// Opens the platform file picker and surfaces any failure to the user.
    void browseFiles() {
      if (_dropState.loading) return;
      _dropState.pickFiles().catchError((e) {
        alertData(
          context: context.mounted ? context : null,
          body: e.toString(),
          type: AlertType.critical,
        );
        _dropState.loading = false;
      });
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Gap(16),
        LinearProgressIndicator(
          value: _dropState.loading ? null : 0,
          minHeight: 8,
          color: theme.colorScheme.secondary,
          backgroundColor: _dropState.loading
              ? theme.colorScheme.secondaryContainer
              : Colors.transparent,
          semanticsLabel: locales.get('label--loading'),
        ),
        LiveAnnouncer(
          message: _dropState.loading ? locales.get('label--loading') : null,
        ),
        DropRegion(
          onDraggingChanged: _dropState.updateDragging,
          onDrop: _dropState.onDroppedFiles,
          child: Material(
            type: MaterialType.transparency,
            child: MergeSemantics(
              child: Semantics(
                button: true,
                label: locales.get('label--drop-zone-hint'),
                onTap: browseFiles,
                child: InkWell(
                  onTap: browseFiles,
                  child: ExcludeSemantics(
                    child: Container(
                      height: kMinInteractiveDimension * 4,
                      width: double.maxFinite,
                      margin: const EdgeInsets.all(16),
                      child: CustomPaint(
                        foregroundPainter: _DashedBorderPainter(
                          color: _dropState.dragging
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                          radius: 12,
                          strokeWidth: 2,
                          dashLength: 10,
                          gapLength: 5,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(12),
                              ),
                              color: _dropState.dragging
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerLow,
                            ),
                            child: ClipRRect(
                              clipBehavior: Clip.hardEdge,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(12),
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    locales.get('label--drop-files-here'),
                                    textAlign: TextAlign.center,
                                    style: textTheme.titleMedium?.copyWith(
                                      color: _dropState.dragging
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Keyboard and screen reader accessible alternative to the drop target.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _dropState.loading ? null : browseFiles,
              icon: const Icon(Icons.folder_open),
              label: Text(locales.get('label--browse-files')),
            ),
          ),
        ),
        ...List<Widget>.generate(itemCount * 2, (i) {
          if (i.isOdd) return const Divider();
          final index = i ~/ 2;
          final item = _dropState.mediaList[index];
          final leading = _iconFor(item);
          final iconColor = _colorFor(item, theme);

          Widget? trailing;
          final removeButton = IconButton(
            tooltip: locales.get('label--remove'),
            color: theme.colorScheme.error,
            icon: const Icon(Icons.delete),
            onPressed: _dropState.loading
                ? null
                : () {
                    _dropState.removeMedia(index);
                  },
          );

          Widget subtitle = Text(
            '${item.contentType} • ${FormatData.formatBytes(item.size)}',
            style: textTheme.bodyMedium,
          );

          if (item.status == MediaDataUploadStatus.uploading) {
            trailing = const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          } else if (item.status == MediaDataUploadStatus.failed) {
            trailing = removeButton;
            subtitle = Text(
              item.error ?? 'Failed',
              style: textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.error,
              ),
            );
          } else if (item.status == MediaDataUploadStatus.pending) {
            trailing = removeButton;
          }
          return ListTile(
            iconColor: iconColor,
            leading: leading,
            title: Text(item.fileName),
            subtitle: subtitle,
            trailing: trailing,
            selected: item.status == MediaDataUploadStatus.uploading,
          );
        }),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 16,
            children: [
              if (_dropState.mediaList.isNotEmpty && !_dropState.loading)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.cloud_upload),
                  onPressed: () {
                    _dropState.upload(
                      context: context,
                      path: widget.path,
                      expiry: widget.expiry,
                      callback: widget.callback,
                    );
                  },
                  label: Text(locales.get('label--upload')),
                ),
              if (_dropState.mediaList.isNotEmpty && !_dropState.loading)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    foregroundColor: theme.colorScheme.onErrorContainer,
                    backgroundColor: theme.colorScheme.errorContainer,
                  ),
                  onPressed: () {
                    if (_dropState.loading) return;
                    _dropState.clearAll();
                  },
                  label: Text(locales.get('label--clear-all')),
                  icon: const Icon(Icons.clear_all),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Paints a dashed rounded-rectangle border around a drop target.
///
/// This replaces the external `dotted_border` package with a small in-package
/// painter, trimming the dependency surface. The border is stroked along a
/// rounded rectangle inset by half [strokeWidth] so the line stays fully inside
/// the painted bounds, using [dashLength] on and [gapLength] off segments.
class _DashedBorderPainter extends CustomPainter {
  /// Creates a dashed border painter with the given geometry and [color].
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  /// Stroke color of the dashes.
  final Color color;

  /// Corner radius of the rounded rectangle.
  final double radius;

  /// Width of the stroked dashes.
  final double strokeWidth;

  /// Length of each painted dash segment.
  final double dashLength;

  /// Length of the gap between dashes.
  final double gapLength;

  /// Strokes the dashed rounded rectangle onto [canvas].
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashLength),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  /// Repaints only when the color or geometry changes.
  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength;
}
