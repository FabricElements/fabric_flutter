import 'package:json_annotation/json_annotation.dart';

part 'media_data.g.dart';

/// Stores a serialized media payload.
///
/// This model keeps the raw content alongside metadata needed to reconstruct a
/// file preview, download, or upload request across application boundaries.
@JsonSerializable(explicitToJson: true)
class MediaData {
  /// Contains the encoded media bytes or transport-safe payload.
  String data;

  /// Describes the MIME type used to interpret [data].
  String contentType;

  /// Stores the file extension used for naming and local handling.
  String extension;

  /// Provides the original or display file name.
  String fileName;

  /// Stores the media height when the asset has visual dimensions.
  int? height;

  /// Stores the media width when the asset has visual dimensions.
  int? width;

  /// Records the file size in bytes.
  int size;

  /// Creates serialized media metadata.
  MediaData({
    required this.data,
    required this.contentType,
    required this.extension,
    required this.fileName,
    required this.size,
    this.width,
    this.height,
  });

  /// Builds [MediaData] from serialized JSON.
  ///
  /// A `null` payload becomes an empty map so callers can deserialize optional
  /// media fields without guarding for missing data first.
  factory MediaData.fromJson(Map<String, dynamic>? json) =>
      _$MediaDataFromJson(json ?? {});

  /// Converts this media payload into JSON.
  Map<String, dynamic> toJson() => _$MediaDataToJson(this);
}
