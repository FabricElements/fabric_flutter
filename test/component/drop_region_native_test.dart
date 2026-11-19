import 'dart:convert';
import 'dart:io';

import 'package:fabric_flutter/component/drop_region_native.dart';
import 'package:fabric_flutter/helper/drop_file_format.dart';
import 'package:file_drop/file_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dispatches a native drag event into [DesktopDrop] as if the platform sent it.
///
/// `setMockMethodCallHandler` only intercepts outbound calls, so a platform to
/// Dart event has to go through the test binary messenger's inbound path, which
/// is what the plugin's own handler is registered against.
Future<void> _emitEvent(String method, Map<String, Object?> arguments) {
  final call = MethodCall(method, arguments);
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        DesktopDrop.channel.name,
        DesktopDrop.channel.codec.encodeMethodCall(call),
        null,
      );
}

/// Dispatches a drop and waits for it to be delivered.
///
/// A drop reads the dropped files through `dart:io`, whose completions are
/// delivered by the real event loop. `testWidgets` bodies run inside a
/// `FakeAsync` zone that never lets those completions fire, so the dispatch has
/// to happen inside [WidgetTester.runAsync].
Future<void> _emitDrop(
  WidgetTester tester,
  String method,
  Map<String, Object?> arguments,
) async {
  await tester.runAsync(() => _emitEvent(method, arguments));
  await tester.pumpAndSettle();
}

/// A payload entry describing a dropped file at [path].
Map<String, Object?> _fileEntry(String path, {String? name, String? mimeType}) {
  return <String, Object?>{'path': path, 'name': ?name, 'mimeType': ?mimeType};
}

/// The centre of the drop region, in global coordinates.
///
/// The native plugin hit-tests the pointer against the target's bounds, so
/// events have to be dispatched at a point inside the laid-out region.
Offset _regionCentre(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(find.byKey(_childKey));
  return box.localToGlobal(box.size.center(Offset.zero));
}

/// Identifies the region's child so its bounds can be measured.
const Key _childKey = Key('drop-region-child');

void main() {
  group('DropRegion', () {
    late List<DropZoneFile> dropped;
    late List<bool> dragging;
    late Directory tempDir;

    setUp(() {
      dropped = <DropZoneFile>[];
      dragging = <bool>[];
      tempDir = Directory.systemTemp.createTempSync('drop_region_native_test');
      DesktopDrop.instance.resetForTesting();
    });

    tearDown(() {
      DesktopDrop.instance.resetForTesting();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    /// Pumps a [DropRegion] wrapping an opaque, sized child.
    Future<void> pumpRegion(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DropRegion(
                onDrop: (files) async => dropped.addAll(files),
                onDraggingChanged: dragging.add,
                child: Container(
                  key: _childKey,
                  width: 200,
                  height: 200,
                  color: const Color(0xFF2196F3),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    /// Writes a file with [contents] into the test's temp directory.
    File writeTempFile(String name, String contents) {
      final file = File('${tempDir.path}/$name')
        ..writeAsBytesSync(utf8.encode(contents));
      return file;
    }

    group('dragging', () {
      testWidgets('should report hover true when a drag enters', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);

        // Act
        await _emitEvent('onDragEntered', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'offer': <String, Object?>{
            'files': <Object?>[_fileEntry('/tmp/photo.png')],
            'isComplete': true,
          },
        });
        await tester.pump();

        // Assert
        expect(dragging, <bool>[true]);
      });

      testWidgets('should report hover false when the drag leaves', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        await _emitEvent('onDragEntered', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'offer': <String, Object?>{
            'files': <Object?>[_fileEntry('/tmp/photo.png')],
            'isComplete': true,
          },
        });
        await tester.pump();

        // Act
        await _emitEvent('onDragExited', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
        });
        await tester.pump();

        // Assert
        expect(dragging, <bool>[true, false]);
      });

      testWidgets('should not repeat hover true for a continuing drag', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        final offer = <String, Object?>{
          'files': <Object?>[_fileEntry('/tmp/photo.png')],
          'isComplete': true,
        };

        // Act
        await _emitEvent('onDragEntered', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'offer': offer,
        });
        await tester.pump();
        await _emitEvent('onDragUpdated', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'offer': offer,
        });
        await tester.pump();

        // Assert
        expect(dragging, <bool>[true]);
      });

      testWidgets('should ignore a drag that never enters the region', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);

        // Act
        await _emitEvent('onDragEntered', <String, Object?>{
          'x': centre.dx + 1000,
          'y': centre.dy + 1000,
          'offer': <String, Object?>{
            'files': <Object?>[_fileEntry('/tmp/photo.png')],
            'isComplete': true,
          },
        });
        await tester.pump();

        // Assert
        expect(dragging, isEmpty);
      });
    });

    group('dropping', () {
      testWidgets('should deliver a dropped file as a DropZoneFile', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        final file = writeTempFile('photo.png', 'png-bytes');

        // Act
        await _emitDrop(tester, 'onDragDone', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'items': <Object?>[
            _fileEntry(file.path, name: 'photo.png', mimeType: 'image/png'),
          ],
        });

        // Assert
        expect(dropped, hasLength(1));
        expect(dropped.single.name, 'photo.png');
        expect(dropped.single.mimeType, 'image/png');
        expect(dropped.single.size, 9);
        expect(utf8.decode(dropped.single.bytes), 'png-bytes');
      });

      testWidgets('should infer the MIME type when the platform omits one', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        final file = writeTempFile('photo.png', 'png-bytes');

        // Act
        await _emitDrop(tester, 'onDragDone', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'items': <Object?>[_fileEntry(file.path)],
        });

        // Assert
        expect(dropped, hasLength(1));
        expect(dropped.single.name, 'photo.png');
        expect(dropped.single.mimeType, 'image/png');
      });

      testWidgets('should clear hover before delivering the files', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        final file = writeTempFile('photo.png', 'png-bytes');
        await _emitEvent('onDragEntered', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'offer': <String, Object?>{
            'files': <Object?>[_fileEntry(file.path)],
            'isComplete': true,
          },
        });
        await tester.pump();

        // Act
        await _emitDrop(tester, 'onDragDone', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'items': <Object?>[_fileEntry(file.path)],
        });

        // Assert
        expect(dragging, <bool>[true, false]);
        expect(dropped, hasLength(1));
      });

      testWidgets('should deliver every file in a multi-file drop', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        final first = writeTempFile('photo.png', 'one');
        final second = writeTempFile('doc.pdf', 'two');

        // Act
        await _emitDrop(tester, 'onDragDone', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'items': <Object?>[
            _fileEntry(first.path, name: 'photo.png'),
            _fileEntry(second.path, name: 'doc.pdf'),
          ],
        });

        // Assert
        expect(dropped.map((file) => file.name), <String>[
          'photo.png',
          'doc.pdf',
        ]);
      });

      testWidgets('should skip a dropped string item', (tester) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        final file = writeTempFile('photo.png', 'png-bytes');

        // Act
        await _emitDrop(tester, 'onDragDone', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'items': <Object?>[
            <String, Object?>{'kind': 'string', 'value': 'plain text'},
            _fileEntry(file.path, name: 'photo.png'),
          ],
        });

        // Assert
        expect(dropped, hasLength(1));
        expect(dropped.single.name, 'photo.png');
      });

      testWidgets('should deliver a csv string item as a csv file', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        const contents = 'name,email\nAda,ada@example.com\n';

        // Act
        await _emitDrop(tester, 'onDragDone', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'items': <Object?>[
            <String, Object?>{
              'kind': 'string',
              'mimeType': 'text/plain',
              'value': contents,
            },
          ],
        });

        // Assert
        expect(dropped, hasLength(1));
        expect(dropped.single.unreadable, isFalse);
        expect(dropped.single.name, 'contacts.csv');
        expect(dropped.single.mimeType, 'text/csv');
        expect(dropped.single.size, contents.length);
        expect(utf8.decode(dropped.single.bytes), contents);
      });

      testWidgets('should deliver a vcard string item as a vcf file', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        const contents = 'BEGIN:VCARD\nEND:VCARD\n';

        // Act
        await _emitDrop(tester, 'onDragDone', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'items': <Object?>[
            <String, Object?>{
              'kind': 'string',
              'mimeType': 'text/vcard',
              'value': contents,
            },
          ],
        });

        // Assert
        expect(dropped, hasLength(1));
        expect(dropped.single.name, 'contact.vcf');
        expect(dropped.single.size, contents.length);
        expect(utf8.decode(dropped.single.bytes), contents);
      });

      testWidgets('should keep csv string file names unique in one drop', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        String stringItem(String value) => value;

        // Act
        await _emitDrop(tester, 'onDragDone', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'items': <Object?>[
            <String, Object?>{
              'kind': 'string',
              'mimeType': 'text/csv',
              'value': stringItem('a,b\n1,2\n'),
            },
            <String, Object?>{
              'kind': 'string',
              'mimeType': 'text/csv',
              'value': stringItem('c,d\n3,4\n'),
            },
          ],
        });

        // Assert
        expect(dropped.map((file) => file.name), <String>[
          'contacts.csv',
          'contacts-2.csv',
        ]);
      });

      testWidgets('should deliver a dropped directory as unreadable', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        final directory = Directory('${tempDir.path}/folder')..createSync();
        final file = writeTempFile('photo.png', 'png-bytes');

        // Act
        await _emitDrop(tester, 'onDragDone', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'items': <Object?>[
            <String, Object?>{'path': directory.path, 'isDirectory': true},
            _fileEntry(file.path, name: 'photo.png'),
          ],
        });

        // Assert
        expect(dropped, hasLength(2));
        expect(dropped.first.unreadable, isTrue);
        expect(dropped.last.name, 'photo.png');
        expect(dropped.last.unreadable, isFalse);
      });

      testWidgets('should flag a drop with no file as unreadable', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);

        // Act
        await _emitDrop(tester, 'onDragDone', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'items': <Object?>[
            <String, Object?>{'kind': 'string', 'value': 'plain text'},
          ],
        });

        // Assert
        expect(dropped.single.unreadable, isTrue);
        expect(dropped.single.name, isEmpty);
      });

      testWidgets('should flag a file that cannot be read as unreadable', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        final missing = File('${tempDir.path}/missing.png');

        // Act
        await _emitDrop(tester, 'onDragDone', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'items': <Object?>[_fileEntry(missing.path, name: 'missing.png')],
        });

        // Assert
        expect(dropped.single.unreadable, isTrue);
        expect(dropped.single.name, 'missing.png');
      });

      testWidgets('should not deliver a drop outside the region', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        final file = writeTempFile('photo.png', 'png-bytes');

        // Act
        await _emitDrop(tester, 'onDragDone', <String, Object?>{
          'x': centre.dx + 1000,
          'y': centre.dy + 1000,
          'items': <Object?>[_fileEntry(file.path, name: 'photo.png')],
        });

        // Assert
        expect(dropped, isEmpty);
      });

      testWidgets('should deliver a drop reported as a copy operation', (
        tester,
      ) async {
        // Arrange
        await pumpRegion(tester);
        final centre = _regionCentre(tester);
        final file = writeTempFile('photo.png', 'png-bytes');

        // Act
        await _emitDrop(tester, 'performOperation', <String, Object?>{
          'x': centre.dx,
          'y': centre.dy,
          'operation': 'copy',
          'items': <Object?>[_fileEntry(file.path, name: 'photo.png')],
        });

        // Assert
        expect(dropped, hasLength(1));
        expect(dropped.single.name, 'photo.png');
      });
    });
  });
}
