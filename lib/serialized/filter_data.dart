import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import '../component/input_data.dart';
import '../helper/enum_data.dart';
import '../helper/options.dart';
import '../helper/utils.dart';

part 'filter_data.g.dart';

enum FilterOperator {
  equal,
  notEqual,
  contains,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  between,
  any,
  sort,
}

enum FilterOrder {
  asc,
  desc,
}

/// Filter Data
@JsonSerializable(explicitToJson: true)
class FilterData {
  ///
  String id;

  ///
  @JsonKey(includeToJson: false, includeFromJson: false)
  String label;

  ///
  InputDataType type;

  ///
  @JsonKey(includeToJson: false, includeFromJson: false)
  List<dynamic> enums;

  ///
  @JsonKey(includeToJson: false, includeFromJson: false)
  List<ButtonOptions> options;

  ///
  FilterOperator? operator;

  ///
  @JsonKey(includeIfNull: true)
  dynamic value;

  ///
  int index;

  ///
  @JsonKey(includeToJson: false, includeFromJson: false)
  Function(FilterData)? onChange;

  FilterData({
    required this.id,
    this.operator,
    this.value,
    this.label = 'Unknown',
    this.type = InputDataType.string,
    this.enums = const [],
    this.options = const [],
    this.index = 0,
    this.onChange,
  });

  /// Convert value from JSON
  dynamic _valueToJson() {
    dynamic finalValue;
    if (value is bool) {
      finalValue = value;
    } else {
      try {
        switch (type) {
          case InputDataType.date:
          case InputDataType.dateTime:
          case InputDataType.timestamp:
            if (operator == FilterOperator.between) {
              finalValue = [
                (value[0] as DateTime?)?.toIso8601String(),
                (value[1] as DateTime?)?.toIso8601String(),
              ];
            } else {
              finalValue = (value as DateTime?)?.toIso8601String();
            }
            break;
          case InputDataType.time:
          case InputDataType.email:
          case InputDataType.double:
          case InputDataType.int:
          case InputDataType.text:
          case InputDataType.string:
          case InputDataType.phone:
          case InputDataType.url:
            if (operator == FilterOperator.between) {
              finalValue = [value[0], value[1]];
            } else {
              finalValue = value;
            }
            break;
          case InputDataType.enums:
            if (value is! bool) {
              finalValue = EnumData.describe(value);
            }
            break;
          case InputDataType.dropdown:
          case InputDataType.radio:
            finalValue = value;
            break;
          case InputDataType.secret:
            finalValue = value.toString();
            break;
          case InputDataType.bool:
            finalValue = value;
            break;
        }
      } catch (e) {
        if (kDebugMode) print(e);
      }
    }
    return finalValue;
  }

  factory FilterData.fromJson(Map<String, dynamic>? json) {
    Map<String, dynamic> jsonData = json ?? {};
    dynamic base = _$FilterDataFromJson(jsonData);
    dynamic baseValue = jsonData['value'];
    dynamic finalValue;

    /// Convert value
    switch (base.type) {
      case InputDataType.date:
      case InputDataType.dateTime:
      case InputDataType.timestamp:
        if (base.operator == FilterOperator.between) {
          finalValue = [
            Utils.dateTimeFromJson(baseValue[0]),
            Utils.dateTimeFromJson(baseValue[1]),
          ];
        } else {
          finalValue = Utils.dateTimeFromJson(baseValue);
        }
        break;
      default:
        finalValue = baseValue;
        break;
    }

    /// override value
    base.value = finalValue;
    return base;
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> base = _$FilterDataToJson(this);
    return {
      ...base,
      'value': _valueToJson(),
    };
  }

  /// clear filter data
  clear() {
    operator = null;
    value = null;
    index = 0;
  }
}
