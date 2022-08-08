library fabric_flutter;

import 'package:json_annotation/json_annotation.dart';

part 'gsm_data.g.dart';

enum CharSet {
  unicode,
  // "GSM 03.38"
  gsm
}

@JsonSerializable(explicitToJson: true)
class GSMData {
  final int segments;
  final int charsLeft;
  final CharSet charSet;
  final List<String> parts;

  GSMData({
    required this.segments,
    required this.charsLeft,
    required this.charSet,
    required this.parts,
  });

  factory GSMData.fromJson(Map<String, dynamic>? json) =>
      _$GSMDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$GSMDataToJson(this);
}
