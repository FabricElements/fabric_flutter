import 'package:json_annotation/json_annotation.dart';

part 'filter_data.g.dart';

enum FilterDataOptions {
  equal,
  notEqual,
  contains,
  between,
  greaterThan,
  lessThan,
  any,
}

/// Filter Data
@JsonSerializable(explicitToJson: true)
class FilterData {
  String id;
  FilterDataOptions option;

  /// Non numerical
  dynamic equal; // is
  dynamic notEqual; // not is
  dynamic contains;

  /// Numerical
  List<dynamic>? between;

  /// Any options
  dynamic greaterThan;
  dynamic lessThan;

  bool? any;

  FilterData({
    required this.id,
    this.equal,
    this.notEqual,
    this.contains,
    this.between,
    this.greaterThan,
    this.lessThan,
    this.any,
    this.option = FilterDataOptions.any,
  });

  factory FilterData.fromJson(Map<String, dynamic>? json) =>
      _$FilterDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$FilterDataToJson(this);

  /// TODO: encode to base64
  /// TODO: decode from base64 and return class
// String encode() => base64.encode(toJson().);
}
