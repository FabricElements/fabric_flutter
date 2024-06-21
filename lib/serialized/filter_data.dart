import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import '../component/input_data.dart';
import '../helper/enum_data.dart';
import '../helper/log_color.dart';
import '../helper/options.dart';
import '../helper/utils.dart';

part 'filter_data.g.dart';

/// Filter Operator
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
  whereIn,
}

/// Filter Order
enum FilterOrder {
  asc,
  desc,
}

/// Filter Data
@JsonSerializable(explicitToJson: true)
class FilterData {
  /// ID
  String id;

  /// Label
  @JsonKey(includeToJson: false, includeFromJson: false)
  String label;

  /// Input Data Type
  /// @see [InputDataType]
  InputDataType type;

  /// Enums List
  @JsonKey(includeToJson: false, includeFromJson: false)
  List<dynamic> enums;

  /// Options List
  /// @see [ButtonOptions]
  @JsonKey(includeToJson: false, includeFromJson: false)
  List<ButtonOptions> options;

  /// Operator
  FilterOperator? operator;

  /// Value
  @JsonKey(includeIfNull: true)
  dynamic value;

  /// Index
  @JsonKey(includeIfNull: true)
  int index;

  /// On Change
  /// @see [FilterData]
  @JsonKey(includeToJson: false, includeFromJson: false)
  Function(FilterData)? onChange;

  /// Group
  @JsonKey(includeToJson: false, includeFromJson: false)
  dynamic group;

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
    this.group,
  });

  /// Convert value to JSON
  dynamic _valueToJson() {
    dynamic finalValue;
    final isSort = operator == FilterOperator.sort || id == 'sort';
    if (isSort) {
      finalValue = value != null && value[0] != null && value[1] != null
          ? [value[0], value[1]]
          : null;
    } else if (value is bool) {
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
          case InputDataType.int:
          case InputDataType.double:
          case InputDataType.currency:
          case InputDataType.percent:
          case InputDataType.text:
          case InputDataType.string:
          case InputDataType.phone:
          case InputDataType.url:
            switch (operator) {
              case FilterOperator.between:
              case FilterOperator.whereIn:
                finalValue = value != null && value.isNotEmpty ? value : [];
                break;
              default:
                finalValue = value;
            }
            break;
          case InputDataType.enums:
            if (value is! bool) {
              switch (operator) {
                case FilterOperator.between:
                case FilterOperator.whereIn:
                  finalValue = (value as List<dynamic>)
                      .map((e) => EnumData.describe(e))
                      .toList();
                  break;
                default:
                  finalValue = EnumData.describe(value);
              }
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
        debugPrint(LogColor.error('ValueToJson: $e'));
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
        switch (base.operator) {
          case FilterOperator.between:
          case FilterOperator.whereIn:
            finalValue = (baseValue as List<dynamic>)
                .map((e) => Utils.dateTimeFromJson(e))
                .toList();
            break;
          default:
            finalValue = Utils.dateTimeFromJson(baseValue);
        }
        break;
      // case InputDataType.enums:
      //   switch (base.operator) {
      //     case FilterOperator.between:
      //     case FilterOperator.whereIn:
      //       finalValue = (baseValue as List<dynamic>)
      //           .map((e) => EnumData.describe(e))
      //           .toList();
      //       break;
      //     default:
      //       finalValue = EnumData.describe(base.enums, baseValue);
      //   }
      //   break;
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
    index = 0;
    operator = null;
    value = null;
  }
}
