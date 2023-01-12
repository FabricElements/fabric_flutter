import 'package:fabric_flutter/helper/enum_data.dart';
import 'package:json_annotation/json_annotation.dart';

import '../component/input_data.dart';
import '../helper/format_data.dart';
import '../helper/options.dart';

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
  @JsonKey(ignore: true)
  String label;

  ///
  InputDataType type;

  ///
  @JsonKey(ignore: true)
  List<dynamic> enums;

  ///
  @JsonKey(ignore: true)
  List<ButtonOptions> options;

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
    this.type = InputDataType.string,
    this.enums = const [],
    this.options = const [],
    this.index = 0,
    this.onChange,
  });

  factory FilterData.fromJson(Map<String, dynamic>? json) =>
      _$FilterDataFromJson(json ?? {});

  // Map<String, dynamic> toJson() => _$FilterDataToJson(this);

  Map<String, dynamic> toJson() {
    dynamic finalValue;
    if (value is bool) {
      finalValue = value;
    } else {
      try {
        switch (type) {
          case InputDataType.date:
            if (operator == FilterOperator.between) {
              finalValue = [
                FormatData.formatDateShort().format(value[0]),
                FormatData.formatDateShort().format(value[1]),
              ];
            } else {
              finalValue = FormatData.formatDateShort().format(value[0]);
            }
            break;
          case InputDataType.time:
            // if (operator == FilterOperator.between) {
            //   label += value[0].format(context);
            //   label += ' ${locales.get('label--and')} ';
            //   label += value[1].format(context);
            // } else {
            //   label += value.format(context);
            // }
            break;
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
        }
      } catch (e) {
        print(e);
        //
      }
    }
    return <String, dynamic>{
      'id': id,
      'type': _$InputDataTypeEnumMap[type]!,
      'operator': _$FilterOperatorEnumMap[operator],
      'value': finalValue,
      'index': index,
    };
  }

  /// TODO: encode to base64
  /// TODO: decode from base64 and return class
// String encode() => base64.encode(toJson().);
}
