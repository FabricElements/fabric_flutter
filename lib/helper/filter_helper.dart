import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../component/input_data.dart';
import '../serialized/filter_data.dart';
import 'enum_data.dart';

enum SQLQueryType {
  sql,
  openSearch,
  bigQuery,
}

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
        print('value type: ${value.runtimeType} -- ${value.toString()}');
        response =
            value != null ? '"${(value as DateTime).toIso8601String()}"' : null;
        // response = DateFormat('yyyy/MM/dd').format(value as DateTime);
        // response = FormatData.formatDateShort().format(value);
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
        response = value != null ? '"$value"' : null;
        break;
      case InputDataType.dropdown:
      case InputDataType.radio:
        response = null;
        if (value != null) {
          switch (value.runtimeType) {
            case String:
              response = '"$value"';
              break;
            default:
              response = value;
          }
        }
        // response = value != null ? '"$value"' : null;
        break;
      case InputDataType.double:
        response = double.tryParse(value.toString());
        break;
      case InputDataType.int:
        response = int.tryParse(value.toString());
        break;
      case InputDataType.enums:
        response = value != null ? '"${EnumData.describe(value)}"' : null;
        break;
    }
    return response;
  }

  static String _sqlOperator(
    FilterOperator operator,
    SQLQueryType sqlQueryType,
  ) {
    late String operatorResult;
    switch (operator) {
      case FilterOperator.equal:
        operatorResult = '=';
        break;
      case FilterOperator.notEqual:
        switch (sqlQueryType) {
          case SQLQueryType.sql:
          case SQLQueryType.bigQuery:
            operatorResult = '!=';
            break;
          case SQLQueryType.openSearch:
            operatorResult = '<>';
            break;
        }
        break;
      case FilterOperator.contains:
        operatorResult = '=';
        break;
      case FilterOperator.greaterThan:
        operatorResult = '>';
        break;
      case FilterOperator.lessThan:
        operatorResult = '<';
        break;
      case FilterOperator.between:
        // Ignore
        operatorResult = '';
        break;
      case FilterOperator.any:
        operatorResult = '!= null';
        break;
      case FilterOperator.greaterThanOrEqual:
        operatorResult = '>=';
        break;
      case FilterOperator.lessThanOrEqual:
        operatorResult = '<=';
        break;
      case FilterOperator.sort:
        operatorResult = '';
        break;
    }
    return operatorResult;
  }

  /// Returns a SQL query string from a list of filters
  static String? toSQL({
    required table,
    required List<FilterData> filterData,
    int? limit,
    SQLQueryType sqlQueryType = SQLQueryType.sql,
  }) {
    List<FilterData> filters = filter(filters: filterData);
    if (filters.isEmpty) return null;
    String query = 'select * from $table';
    String sort = '';
    int count = 0;
    for (int i = 0; i < filters.length; i++) {
      FilterData filter = filters[i];
      String subQuery = '';
      switch (filter.operator!) {
        case FilterOperator.contains:
          final value = valueFromType(
            dataType: filter.type,
            value: filter.value,
          );
          subQuery +=
              '${filter.id} ${_sqlOperator(filter.operator!, sqlQueryType)} $value';
          break;
        case FilterOperator.equal:
        case FilterOperator.notEqual:
        case FilterOperator.greaterThan:
        case FilterOperator.greaterThanOrEqual:
        case FilterOperator.lessThanOrEqual:
        case FilterOperator.lessThan:
          final value = valueFromType(
            dataType: filter.type,
            value: filter.value,
          );
          subQuery +=
              '${filter.id} ${_sqlOperator(filter.operator!, sqlQueryType)} $value';
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
          subQuery +=
              '${filter.id} ${_sqlOperator(filter.operator!, sqlQueryType)}';
          break;
        case FilterOperator.sort:
          if (filter.value == null ||
              filter.value == true ||
              filter.value[0] == null ||
              filter.value[1] == null) {
            break;
          }
          // final sortBy = valueFromType(
          //   dataType: InputDataType.dropdown,
          //   value: filter.value[0],
          // );
          final sortBy = filter.value[0];
          final order = filter.value[1] ?? EnumData.describe(FilterOrder.asc);
          sort += 'ORDER BY $sortBy';
          if (order != null) sort += ' $order';
          break;
      }

      if (subQuery.isEmpty) continue;
      late String operator;
      count++;
      if (count == 1) {
        operator = 'where';
      } else {
        operator = 'and';
      }
      query += ' $operator $subQuery';
    }
    if (sort.isNotEmpty) query += ' $sort';
    if (limit != null) query += ' limit $limit';
    query += ';';
    return query;
  }

  static String? toSQLEncoded({
    required table,
    required List<FilterData> filterData,
    SQLQueryType sqlQueryType = SQLQueryType.sql,
    int? limit,
  }) {
    final sqlQuery = toSQL(
      table: table,
      filterData: filterData,
      limit: limit,
      sqlQueryType: sqlQueryType,
    );
    if (sqlQuery == null) return null;
    debugPrint(sqlQuery);
    Codec<String, String> stringToBase64 = utf8.fuse(base64);
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
    final filterDataValid = filter(filters: filters);
    if (filterDataValid.isEmpty) return null;
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
