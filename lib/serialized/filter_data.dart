import 'package:json_annotation/json_annotation.dart';

import '../component/input_data.dart';
import '../helper/options.dart';

part 'filter_data.g.dart';

enum FilterOperator {
  equal,
  notEqual,
  contains,
  greaterThan,
  lessThan,
  between,
  any,
}

/// Filter Data
@JsonSerializable(explicitToJson: true)
class FilterData {
  ///
  String id;

  ///
  @JsonKey(ignore: true)
  final String label;

  ///
  final InputDataType type;

  ///
  @JsonKey(ignore: true)
  final List<dynamic> enums;

  ///
  @JsonKey(ignore: true)
  final List<ButtonOptions> options;

  ///
  FilterOperator? operator;

  ///
  @JsonKey(includeIfNull: true)
  dynamic value;

  ///
  int index;

  ///
  @JsonKey(ignore: true)
  Function(FilterData)? onChange;

  FilterData({
    required this.id,
    this.operator,
    this.value,
    this.label = 'Unknown',
    required this.type,
    this.enums = const [],
    this.options = const [],
    this.index = 0,
    this.onChange,
  });

  factory FilterData.fromJson(Map<String, dynamic>? json) =>
      _$FilterDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$FilterDataToJson(this);

  /// TODO: encode to base64
  /// TODO: decode from base64 and return class
// String encode() => base64.encode(toJson().);
}
