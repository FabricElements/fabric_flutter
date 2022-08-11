library fabric_flutter;

import 'package:json_annotation/json_annotation.dart';

part 'media_data.g.dart';

@JsonSerializable(explicitToJson: true)
class MediaData {
  String data;
  String contentType;
  String extension;
  String fileName;

  MediaData({
    required this.data,
    required this.contentType,
    required this.extension,
    required this.fileName,
  });

  factory MediaData.fromJson(Map<String, dynamic>? json) =>
      _$MediaDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$MediaDataToJson(this);
}
