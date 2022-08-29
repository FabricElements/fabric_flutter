import 'package:json_annotation/json_annotation.dart';

part 'gsm_data.g.dart';

enum CharSet {
  unicode,
  // "GSM 03.38"
  gsm
}

@JsonSerializable(explicitToJson: true)
class GSMData {
  final String text;
  final int segments;
  final int charsLeft;
  final CharSet charSet;
  final List<String> parts;
  final int chars;

  GSMData({
    required this.text,
    required this.segments,
    required this.charsLeft,
    required this.charSet,
    required this.parts,
  }) : chars = text.length;

  factory GSMData.fromJson(Map<String, dynamic>? json) =>
      _$GSMDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$GSMDataToJson(this);
}
