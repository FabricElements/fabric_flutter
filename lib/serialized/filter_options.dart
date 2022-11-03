import 'package:json_annotation/json_annotation.dart';

import '../component/input_data.dart';

part 'filter_options.g.dart';

/// Filter Options
@JsonSerializable(explicitToJson: true)
class FilterOptions {
  String id;
  final String label;
  final InputDataType type;
  @JsonKey(includeIfNull: false)
  final List<dynamic>? options;
  @JsonKey(includeIfNull: false)
  dynamic value;

  FilterOptions({
    required this.id,
    required this.label,
    required this.type,
    this.options,
    this.value,
  });

  factory FilterOptions.fromJson(Map<String, dynamic>? json) =>
      _$FilterOptionsFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$FilterOptionsToJson(this);
}
