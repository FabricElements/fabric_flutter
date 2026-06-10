import 'package:json_annotation/json_annotation.dart';

part 'gsm_data.g.dart';

/// Enumerates the character encodings used when calculating SMS segments.
///
/// The chosen charset directly affects segment size limits, so it is stored as
/// part of the serialized result rather than inferred later.
enum CharSet {
  /// Indicates that the message requires Unicode encoding.
  unicode,

  // "GSM 03.38"

  /// Indicates that the message fits within the GSM 03.38 character set.
  gsm,
}

/// Stores the result of SMS segmentation analysis.
///
/// This model captures both the original message and derived counters so UIs can
/// explain to users why a message spans multiple SMS segments.
@JsonSerializable(explicitToJson: true)
class GSMData {
  /// Stores the original text that was analyzed.
  final String text;

  /// Stores the total number of SMS segments required.
  final int segments;

  /// Stores how many characters remain in the current segment.
  final int charsLeft;

  /// Stores the charset used to calculate segmentation rules.
  final CharSet charSet;

  /// Stores the text split into transport segments.
  final List<String> parts;

  /// Stores the total character count of [text].
  final int chars;

  /// Creates serialized GSM segmentation data.
  GSMData({
    required this.text,
    required this.segments,
    required this.charsLeft,
    required this.charSet,
    required this.parts,
  }) : chars = text.length;

  /// Builds [GSMData] from serialized JSON.
  ///
  /// A `null` payload is treated as empty input so optional SMS analysis payloads
  /// can still be deserialized safely.
  factory GSMData.fromJson(Map<String, dynamic>? json) =>
      _$GSMDataFromJson(json ?? {});

  /// Converts this GSM analysis into JSON.
  Map<String, dynamic> toJson() => _$GSMDataToJson(this);
}
