import 'dart:convert';

import '../component/input_data.dart';
import '../serialized/filter_data.dart';
import 'enum_data.dart';

class FilterHelper {
  /// Return SQL valid value from data type
  static dynamic valueFromType({
    required InputDataType dataType,
    dynamic value,
  }) {
    if (value == null) return value;
    dynamic response;
    switch (dataType) {
      case InputDataType.date:
        response = '"${(value as DateTime).toIso8601String()}"';
        // response = DateFormat('yyyy/MM/dd').format(value as DateTime);
        break;
      case InputDataType.time:
        // TODO: Handle this case.
        break;
      case InputDataType.email:
      case InputDataType.text:
      case InputDataType.string:
      case InputDataType.phone:
      case InputDataType.secret:
      case InputDataType.url:
      case InputDataType.dropdown:
      case InputDataType.radio:
        response = value != null ? '"$value"' : null;
        break;
      case InputDataType.double:
      case InputDataType.int:
        response = value;
        break;
      case InputDataType.enums:
        response = EnumData.describe(value) != null
            ? '"${EnumData.describe(value)}"'
            : null;
        break;
    }
    return response;
  }

  /// Returns a SQL query string from a list of filters
  static String? toSQL({
    required table,
    required List<FilterData> filterData,
    int? limit,
  }) {
    List<FilterData> filters = filter(filters: filterData, strict: true);
    if (filters.isEmpty) return null;
    String query = 'select * from $table';
    int count = 0;
    for (int i = 0; i < filters.length; i++) {
      FilterData filter = filters[i];
      String subQuery = '';
      switch (filter.operator!) {
        case FilterOperator.equal:
          final value = valueFromType(
            dataType: filter.type,
            value: filter.value,
          );
          subQuery += '${filter.id} = $value';
          break;
        case FilterOperator.notEqual:
          final value = valueFromType(
            dataType: filter.type,
            value: filter.value,
          );
          subQuery += '${filter.id} != $value';
          break;
        case FilterOperator.contains:
          // TODO: Handle this case.
          final value = valueFromType(
            dataType: filter.type,
            value: filter.value,
          );
          subQuery += '${filter.id} = $value';
          break;
        case FilterOperator.greaterThan:
          final value = valueFromType(
            dataType: filter.type,
            value: filter.value,
          );
          subQuery += '${filter.id} >= $value';
          break;
        case FilterOperator.lessThan:
          final value = valueFromType(
            dataType: filter.type,
            value: filter.value,
          );
          subQuery += '${filter.id} <= $value';
          break;
        case FilterOperator.between:
          final value1 = valueFromType(
            dataType: filter.type,
            value: filter.value[0],
          );
          final value2 = valueFromType(
            dataType: filter.type,
            value: filter.value[1],
          );
          subQuery += '${filter.id} >= $value1';
          subQuery += ' and ';
          subQuery += '${filter.id} <= $value2';
          break;
        case FilterOperator.any:
          if (filter.value == null) continue;
          break;
      }

      if (subQuery.isEmpty) continue;
      late String operator;
      count++;
      if (count == 1) {
        operator = 'where ';
      } else {
        operator = 'and ';
      }
      query += ' $operator $subQuery';
    }
    if (limit != null) query += ' limit $limit';
    query += ';';
    return query;
  }

  static String? toSQLEncoded({
    required table,
    required List<FilterData> filterData,
    int? limit,
  }) {
    final sqlQuery = toSQL(table: table, filterData: filterData, limit: limit);
    if (sqlQuery == null) return null;
    print(sqlQuery);
    Codec<String, String> stringToBase64 = utf8.fuse(base64);
    print(stringToBase64.encode(sqlQuery));
    return stringToBase64.encode(sqlQuery);
  }

  static Map<String, dynamic> filterIdsValue(List<FilterData> filterData) {
    Map<String, dynamic> data = {};
    for (int i = 0; i < filterData.length; i++) {
      final item = filterData[i];
      data.putIfAbsent(item.id, () => item.value);
    }
    return data;
  }

  /// Merge filters
  static List<FilterData> merge({
    required List<FilterData> filters,
    required List<FilterData> merge,
  }) {
    List<FilterData> filterDataUpdated = filters;
    for (int i = 0; i < merge.length; i++) {
      try {
        final toMerge = merge[i];
        FilterData item =
            filterDataUpdated.firstWhere((element) => element.id == toMerge.id);
        item.operator = toMerge.operator;
        item.index = toMerge.index;

        if (item.operator == FilterOperator.any) {
          item.value = toMerge.value;
        } else {
          switch (item.type) {
            case InputDataType.enums:
              item.value = EnumData.find(
                enums: item.enums,
                value: toMerge.value,
              );
              break;
            default:
              item.value = toMerge.value;
          }
        }
      } catch (error) {
        print(error);
        //-
      }
    }
    return filterDataUpdated;
  }

  /// Filter list to JSON
  static List<FilterData> filter({
    required List<FilterData> filters,
    bool strict = false,
  }) {
    return filters
        .where((element) =>
            element.value != null &&
            element.operator != null &&
            (strict ? element.operator != FilterOperator.any : true))
        .toList();
  }

  /// Filter list to JSON
  static List<Map<String, dynamic>> toJSON(List<FilterData> filters) {
    return filters
        .where((element) => element.value != null)
        .map((e) => e.toJson())
        .toList();
  }

  /// Filter list from JSON
  static List<FilterData> fromJSON(List<dynamic> filters) {
    return filters
        .map((e) => FilterData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Base64 Encode filters
  static String? encode(List<FilterData> filters) {
    final filterDataValid = FilterHelper.filter(filters: filters);
    dynamic jsonParsed = json.encode(filterDataValid);
    final filterString = jsonParsed.toString();
    Codec<String, dynamic> stringToBase64 = utf8.fuse(base64);

    /// Encode
    return stringToBase64.encode(filterString);
  }

  /// Get value from id
  static dynamic valueFromId({
    required List<FilterData> filters,
    required String id,
  }) {
    final matches = filter(filters: filters, strict: true)
        .where((item) => item.id == id)
        .toList();
    if (matches.isNotEmpty) {
      return matches.first.value;
    }
    return null;
  }
}
