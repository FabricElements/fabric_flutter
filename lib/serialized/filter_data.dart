import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import '../component/input_data.dart';
import '../helper/enum_data.dart';
import '../helper/log_color.dart';
import '../helper/options.dart';
import '../helper/utils.dart';

part 'filter_data.g.dart';

/// Enumerates the comparison operations supported by [FilterData].
///
/// These operators are serialized so filtering rules can be stored, reapplied,
/// and translated into backend queries or local predicates.
enum FilterOperator {
  /// Matches values that are exactly equal.
  equal,

  /// Matches values that are not equal.
  notEqual,

  /// Matches values that contain the provided text or element.
  contains,

  /// Matches values strictly greater than the provided bound.
  greaterThan,

  /// Matches values greater than or equal to the provided bound.
  greaterThanOrEqual,

  /// Matches values strictly less than the provided bound.
  lessThan,

  /// Matches values less than or equal to the provided bound.
  lessThanOrEqual,

  /// Matches values that fall within a two-sided range.
  between,

  /// Matches any value without applying an additional constraint.
  any,

  /// Represents sorting rather than filtering semantics.
  sort,

  /// Matches values that exist in a provided collection.
  whereIn,
}

/// Enumerates the supported sort directions.
enum FilterOrder {
  /// Sorts values in ascending order.
  asc,

  /// Sorts values in descending order.
  desc,
}

/// Stores one serialized filter definition.
///
/// A filter bundles user-facing metadata, value parsing behavior, and optional UI
/// callbacks so the same object can drive both filter editors and query payloads.
@JsonSerializable(explicitToJson: true)
class FilterData {
  /// Stores the stable identifier of the filtered field.
  String id;

  /// Stores the user-facing label for the field.
  @JsonKey(includeToJson: false, includeFromJson: false)
  String label;

  /// Stores the semantic input type used to interpret [value].
  InputDataType type;

  /// Stores enum values that can be selected for enum-based filters.
  @JsonKey(includeToJson: false, includeFromJson: false)
  List<Enum> enums;

  /// Stores button-style options used by some filter editors.
  @JsonKey(includeToJson: false, includeFromJson: false)
  List<ButtonOptions> options;

  /// Stores the selected comparison or sorting operator.
  FilterOperator? operator;

  /// Stores the raw filter value.
  ///
  /// This field remains `dynamic` because dates, booleans, enums, ranges, and
  /// scalar text inputs all use different runtime representations.
  @JsonKey(includeIfNull: true)
  dynamic value;

  /// Stores the display or processing order of the filter.
  @JsonKey(includeIfNull: true)
  int index;

  /// Stores a callback invoked when the filter changes in memory.
  ///
  /// The callback is excluded from JSON because executable closures cannot be
  /// serialized and only make sense inside the current process.
  @JsonKey(includeToJson: false, includeFromJson: false)
  Function(FilterData)? onChange;

  /// Stores an arbitrary grouping token used by the UI.
  @JsonKey(includeToJson: false, includeFromJson: false)
  dynamic group;

  /// Creates serialized filter data.
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

  /// Converts [value] into a JSON-safe representation.
  ///
  /// Serialization depends on both [type] and [operator]. For example, date
  /// ranges become ISO 8601 string lists, enum values are mapped to descriptive
  /// strings, and sort filters preserve the field and direction pair.
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

  /// Builds [FilterData] from serialized JSON.
  ///
  /// During deserialization the raw JSON `value` is converted back into richer
  /// runtime types, such as [DateTime] objects for date-based filters. Unknown or
  /// unsupported shapes are preserved as-is to avoid losing user input.
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

  /// Converts this filter into JSON.
  ///
  /// The generated serializer handles the static fields, while `_valueToJson`
  /// applies the custom value conversion rules needed by dynamic filter inputs.
  Map<String, dynamic> toJson() {
    Map<String, dynamic> base = _$FilterDataToJson(this);
    return {...base, 'value': _valueToJson()};
  }

  /// Resets the filter back to an unconfigured state.
  ///
  /// This keeps the filter object reusable in the UI without replacing the field
  /// metadata or reallocating a new instance.
  void clear() {
    index = 0;
    operator = null;
    value = null;
  }
}
