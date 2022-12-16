import 'package:json_annotation/json_annotation.dart';

import 'filter_data.dart';

part 'filter_list.g.dart';

/// Filter Data
@JsonSerializable(explicitToJson: true)
class FilterList {
  List<FilterData> filters;

  FilterList({
    required this.filters,
  });

  factory FilterList.fromJson(Map<String, dynamic>? json) =>
      _$FilterListFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$FilterListToJson(this);

  /// TODO: encode to base64
  /// TODO: decode from base64 and return class
// String encode() => base64.encode(toJson().);
}
