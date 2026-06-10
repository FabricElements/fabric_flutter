import 'package:flutter/widgets.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helper/utils.dart';

part 'logs_data.g.dart';

/// Stores one serialized log entry.
///
/// The payload combines plain-text content, structured metadata, and an optional
/// prebuilt widget so the same model can support persistence and rich UI display.
///
/// Example:
/// ----------------------------------------------------
///     {
///       'text':
///           '{@Vcr3IZKdvqepEj51vjM8xqLxzfq1} Vestibulum commodo {@VnCYNfYzlVQc3fCAJH2LyNv9vGj2} demo {porttitor} felis.',
///       'id': 'demo',
///       'timestamp': "2021-11-09T20:23:27"
///     }
@JsonSerializable(explicitToJson: true)
class LogsData {
  /// Stores the identifier used to correlate this log entry.
  final dynamic id;

  /// Stores the plain-text log message.
  final String? text;

  /// Stores when the log entry occurred.
  ///
  /// Custom JSON conversion is used so incoming timestamps can be normalized by
  /// shared utility code instead of duplicating parsing logic here.
  @JsonKey(
    fromJson: Utils.dateTimeFromJson,
    toJson: Utils.dateToJson,
    includeIfNull: false,
    defaultValue: null,
  )
  final DateTime? timestamp;

  /// Stores structured log metadata for downstream processing.
  final Map<dynamic, dynamic>? data;

  /// Stores an optional widget representation used only in memory.
  ///
  /// This field is excluded from JSON because widgets cannot be serialized and
  /// are only meaningful while the current Flutter process is running.
  @JsonKey(includeToJson: false, includeFromJson: false)
  Widget? child;

  /// Creates a serialized log entry.
  LogsData({this.id, this.text, this.timestamp, this.data, this.child});

  /// Builds [LogsData] from serialized JSON.
  ///
  /// A `null` payload is treated as empty input so optional logs can be
  /// deserialized into a predictable object.
  factory LogsData.fromJson(Map<String, dynamic>? json) =>
      _$LogsDataFromJson(json ?? {});

  /// Converts this log entry into JSON.
  Map<String, dynamic> toJson() => _$LogsDataToJson(this);
}
