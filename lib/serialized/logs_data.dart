import 'package:flutter/widgets.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helper/utils.dart';

part 'logs_data.g.dart';

/// LogsData serialized data
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
  final dynamic id;
  final String? text;
  @JsonKey(
    fromJson: Utils.dateTimeFromJson,
    toJson: Utils.dateToJson,
    includeIfNull: false,
    defaultValue: null,
  )
  final DateTime? timestamp;
  final Map<dynamic, dynamic>? data;
  @JsonKey(includeToJson: false, includeFromJson: false)
  Widget? child;

  LogsData({this.id, this.text, this.timestamp, this.data, this.child});

  factory LogsData.fromJson(Map<String, dynamic>? json) =>
      _$LogsDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$LogsDataToJson(this);
}
