import 'dart:async';
import 'dart:typed_data';

// XFile is part of the picker contract but only reachable through this
// transitive package.
// ignore: depend_on_referenced_packages
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:fabric_flutter/helper/media_helper.dart';

/// A [PlatformFile] that serves a fixed in-memory byte payload.
final class _FakePlatformFile extends PlatformFile {
  _FakePlatformFile(this._name, this._bytes);

  final String _name;
  final Uint8List _bytes;

  @override
  String get name => _name;

  @override
  Uri get uri => Uri.parse('file:///tmp/$_name');

  @override
  XFile get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => _bytes.lengthInBytes;

  @override
  Future<int?> length() async => _bytes.lengthInBytes;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream<Uint8List>.value(_bytes);
}

/// A [FilePickerPlatform] that hands back canned files and records the picker
/// arguments it was called with.
class _FakeFilePicker extends FilePickerPlatform {
  /// The file returned by the next [pickFiles] call, or an empty list to
  /// simulate the picker being cancelled.
  List<PlatformFile> nextFiles = [];

  /// The type recorded from the most recent [pickFiles] call.
  FileType? recordedType;

  /// The extensions recorded from the most recent [pickFiles] call.
  List<String>? recordedExtensions;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    recordedType = type;
    recordedExtensions = allowedExtensions;
    return nextFiles;
  }
}

/// Encodes a tiny valid JPEG so dimension probes have decodable bytes.
Uint8List _jpegBytes() {
  final image = img.Image(width: 2, height: 2);
  img.fill(image, color: img.ColorRgb8(255, 0, 0));
  return img.encodeJpg(image);
}

/// Builds the magic-number prefix of a high-efficiency photo container.
Uint8List _heicBytes() {
  final bytes = List<int>.filled(32, 0);
  const prefix = 'ftypheic';
  for (var i = 0; i < prefix.length; i++) {
    bytes[4 + i] = prefix.codeUnitAt(i);
  }
  return Uint8List.fromList(bytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final originalPicker = FilePickerPlatform.instance;
  late _FakeFilePicker picker;

  setUp(() {
    picker = _FakeFilePicker();
    FilePickerPlatform.instance = picker;
  });

  tearDown(() {
    FilePickerPlatform.instance = originalPicker;
  });

  group('MediaHelper.getFile', () {
    test(
      'should derive the content type from bytes over the file name',
      () async {
        // Arrange
        picker.nextFiles = [_FakePlatformFile('photo.heic', _jpegBytes())];

        // Act
        final result = await MediaHelper.getFile();

        // Assert
        expect(result.contentType, 'image/jpeg');
        expect(result.extension, 'heic');
      },
    );

    test('should resolve vCard files through the file extension', () async {
      // Arrange
      final vcardText = Uint8List.fromList(
        'BEGIN:VCARD\r\nVERSION:3.0\r\nEND:VCARD\r\n'.codeUnits,
      );
      picker.nextFiles = [_FakePlatformFile('contacts.vcf', vcardText)];

      // Act
      final result = await MediaHelper.getFile();

      // Assert
      expect(result.contentType, 'text/x-vcard');
      expect(result.extension, 'vcf');
    });

    test('should fall back to octet-stream for unresolvable files', () async {
      // Arrange
      final bytes = Uint8List.fromList(List<int>.filled(64, 7));
      picker.nextFiles = [_FakePlatformFile('data.bin', bytes)];

      // Act
      final result = await MediaHelper.getFile();

      // Assert
      expect(result.contentType, 'application/octet-stream');
    });

    test(
      'should pick with the custom type and extensions by default',
      () async {
        // Arrange
        picker.nextFiles = [_FakePlatformFile('photo.heic', _jpegBytes())];

        // Act
        await MediaHelper.getFile(allowedExtensions: ['jpg', 'jpeg']);

        // Assert
        expect(picker.recordedType, FileType.custom);
        expect(picker.recordedExtensions, ['jpg', 'jpeg']);
      },
    );

    test('should forward an explicit type and drop the extensions', () async {
      // Arrange
      picker.nextFiles = [_FakePlatformFile('photo.heic', _jpegBytes())];

      // Act
      await MediaHelper.getFile(
        allowedExtensions: ['jpg', 'jpeg'],
        type: FileType.image,
      );

      // Assert
      expect(picker.recordedType, FileType.image);
      expect(picker.recordedExtensions, isNull);
    });
  });

  group('MediaHelper.getImage', () {
    test(
      'should accept a converted photo whose name keeps its old extension',
      () async {
        // Arrange
        picker.nextFiles = [_FakePlatformFile('photo.heic', _jpegBytes())];

        // Act
        final result = await MediaHelper.getImage(origin: MediaOrigin.files);

        // Assert
        expect(result.extension, 'jpeg');
        expect(result.contentType, 'image/jpeg');
      },
    );

    test('should reject photo bytes that no supported type matches', () async {
      // Arrange
      picker.nextFiles = [_FakePlatformFile('photo.heic', _heicBytes())];

      // Act
      final result = MediaHelper.getImage(origin: MediaOrigin.files);

      // Assert
      await expectLater(
        result,
        throwsA(equals('alert--unsupported-image-format')),
      );
    });
  });
}
