import 'package:json_annotation/json_annotation.dart';

import '../component/input_data.dart';

part 'filter_menu_data.g.dart';

/// Filter Menu Data
@JsonSerializable(explicitToJson: true)
class FilterMenuData {
  final String label;
  final InputDataType type;
  @JsonKey(includeIfNull: false)
  final List<dynamic>? options;
  @JsonKey(includeIfNull: false)
  dynamic value;

  FilterMenuData({
    required this.label,
    required this.type,
    this.options,
    this.value,
  });

  factory FilterMenuData.fromJson(Map<String, dynamic>? json) =>
      _$FilterMenuDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$FilterMenuDataToJson(this);
}
