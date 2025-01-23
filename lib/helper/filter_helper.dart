import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../component/input_data.dart';
import '../serialized/filter_data.dart';
import 'enum_data.dart';
import 'log_color.dart';

/// Supported SQL Query outputs
enum SQLQueryType {
  sql,
  openSearch,
  bigQuery,
}

/// FilterHelper are used by StateShared
class FilterHelper {
  /// Return SQL valid value from data type
  static dynamic valueFromType({
    required InputDataType dataType,
    required SQLQueryType sqlQueryType,
    dynamic value,
  }) {
    if (value == null) return value;
    dynamic response;
    switch (dataType) {
      case InputDataType.date:
        final baseDate = (value as DateTime).toUtc();
        final DateFormat formatter = DateFormat('yyyy-MM-dd');
        final endDateFormatted =
            DateTime.utc(baseDate.year, baseDate.month, baseDate.day);
        final formatted = formatter.format(endDateFormatted);
        response = '"$formatted"';
        break;
      case InputDataType.dateTime:
      case InputDataType.timestamp:
        final baseDate = (value as DateTime).toUtc();
        final formatted = baseDate.toIso8601String();
        response = '"$formatted"';
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
        response = '"$value"';
        break;
      case InputDataType.dropdown:
      case InputDataType.radio:
        response = null;
        if (value != null) {
          switch (value.runtimeType.toString()) {
            case 'String':
              response = '"$value"';
              break;
            default:
              response = value;
          }
        }
        break;
      case InputDataType.double:
      case InputDataType.currency:
      case InputDataType.percent:
        response = double.tryParse(value.toString());
        break;
      case InputDataType.int:
        response = int.tryParse(value.toString());
        break;
      case InputDataType.enums:
        response = '"${EnumData.describe(value)}"';
        break;
      case InputDataType.bool:
        response = value == true;
        break;
    }
    if (dataType == InputDataType.date) {
      switch (sqlQueryType) {
        case SQLQueryType.sql:
          break;
        case SQLQueryType.bigQuery:
          response = 'DATE($response)';
          break;
        case SQLQueryType.openSearch:
          break;
      }
    }
    // dateTime
    if (dataType == InputDataType.dateTime) {
      switch (sqlQueryType) {
        case SQLQueryType.sql:
          break;
        case SQLQueryType.bigQuery:
          response = 'DATETIME($response)';
          break;
        case SQLQueryType.openSearch:
          break;
      }
    }
    // timestamp
    if (dataType == InputDataType.timestamp) {
      switch (sqlQueryType) {
        case SQLQueryType.sql:
          break;
        case SQLQueryType.bigQuery:
          response = 'TIMESTAMP($response)';
          break;
        case SQLQueryType.openSearch:
          break;
      }
    }
    return response;
  }

  static String _sqlOperator({
    required FilterOperator operator,
    required SQLQueryType sqlQueryType,
    dynamic value,
    String? id,
  }) {
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
        switch (sqlQueryType) {
          case SQLQueryType.sql:
          case SQLQueryType.bigQuery:
            operatorResult = 'LIKE';
            break;
          case SQLQueryType.openSearch:
            operatorResult =
                '(SCORE(matchphrasequery($id, \'$value\'), 100) OR SCORE(WILDCARD_QUERY($id, \'*$value*\'), 0.5))';
            break;
        }
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
      case FilterOperator.whereIn:
        operatorResult = 'IN';
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
    String query = 'select * from `$table`';
    String sort = '';
    int count = 0;
    for (int i = 0; i < filters.length; i++) {
      FilterData filter = filters[i];
      String subQuery = '';
      switch (filter.operator!) {
        case FilterOperator.contains:
          if (sqlQueryType == SQLQueryType.openSearch) {
            subQuery += _sqlOperator(
              operator: filter.operator!,
              sqlQueryType: sqlQueryType,
              id: filter.id,
              value: filter.value,
            );
          } else {
            subQuery +=
                '${filter.id} ${_sqlOperator(operator: filter.operator!, sqlQueryType: sqlQueryType)} \'%${filter.value.toString()}%\'';
          }
          break;
        case FilterOperator.equal:
        case FilterOperator.notEqual:
        case FilterOperator.greaterThan:
        case FilterOperator.greaterThanOrEqual:
        case FilterOperator.lessThanOrEqual:
        case FilterOperator.lessThan:
          final value = valueFromType(
            sqlQueryType: sqlQueryType,
            dataType: filter.type,
            value: filter.value,
          );
          subQuery +=
              '${filter.id} ${_sqlOperator(operator: filter.operator!, sqlQueryType: sqlQueryType)} $value';
          break;
        case FilterOperator.between:
          final values = filter.value as List<dynamic>;
          if (values.isEmpty) break;
          final value1 = valueFromType(
            sqlQueryType: sqlQueryType,
            dataType: filter.type,
            value: values[0],
          );
          final value2 = valueFromType(
            sqlQueryType: sqlQueryType,
            dataType: filter.type,
            value: values[1],
          );
          subQuery += '${filter.id} >= $value1';
          subQuery += ' and ';
          subQuery += '${filter.id} <= $value2';
          break;
        case FilterOperator.whereIn:
          final values = filter.value as List<dynamic>;
          if (values.isEmpty) break;
          subQuery +=
              '${filter.id} ${_sqlOperator(operator: filter.operator!, sqlQueryType: sqlQueryType)} (';
          for (int i = 0; i < values.length; i++) {
            final value = valueFromType(
              sqlQueryType: sqlQueryType,
              dataType: filter.type,
              value: values[i],
            );
            subQuery += '$value';
            if (i < values.length - 1) {
              subQuery += ',';
            }
          }
          subQuery += ')';
          break;
        case FilterOperator.any:
          subQuery +=
              '${filter.id} ${_sqlOperator(operator: filter.operator!, sqlQueryType: sqlQueryType)}';
          break;
        case FilterOperator.sort:
          if (filter.value == null || filter.value == true) {
            break;
          }
          // Check if value is a list and is empty
          if (filter.value is List &&
              ((filter.value as List).isEmpty || filter.value[0] == null)) {
            break;
          }
          final sortBy = filter.value[0];
          final order = filter.value[1] ?? EnumData.describe(FilterOrder.desc);
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
    query += ' $sort';
    if (limit != null) query += ' limit $limit';
    query += ';';
    return query;
  }

  /// Filters to SQL encoded value
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
    Codec<String, String> stringToBase64 = utf8.fuse(base64);
    return stringToBase64.encode(sqlQuery);
  }

  /// Ignore duplicated filters
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
    List<FilterData> filterDataUpdated = [...filters];
    for (int i = 0; i < merge.length; i++) {
      FilterData toMerge = merge[i];

      /// Add filter if doesn't exists
      bool filterExists =
          filters.where((element) => element.id == toMerge.id).isNotEmpty;
      if (!filterExists) {
        filterDataUpdated.add(toMerge);
      }

      /// Update existing filter
      FilterData item =
          filterDataUpdated.firstWhere((element) => element.id == toMerge.id);
      item.operator = toMerge.operator;
      item.value = toMerge.value;

      final activeOptions = filter(filters: filterDataUpdated).length;

      if (item.operator == null) {
        // Clear main values
        item.clear();
      } else {
        if (item.index <= 0) item.index = activeOptions + 1;
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
            // element.value != null &&
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
    try {
      final filterDataValid = filter(filters: filters);
      if (filterDataValid.isEmpty) return null;
      dynamic jsonParsed = json.encode(filterDataValid);
      final filterString = jsonParsed.toString();
      Codec<String, dynamic> stringToBase64 = utf8.fuse(base64);

      /// Encode
      return stringToBase64.encode(filterString);
    } catch (e) {
      debugPrint(LogColor.error('FilterHelper.encode: $e'));
      return null;
    }
  }

  /// Decode filters from base64 encoded string
  static List<FilterData> decode(String? filters) {
    List<FilterData> response = [];
    if (filters != null) {
      Codec<String, dynamic> stringToBase64 = utf8.fuse(base64);
      final decodeBase = stringToBase64.decode(filters);
      final decodeJSON = (json.decode(decodeBase) as List<dynamic>)
          .map((e) => FilterData.fromJson(e))
          .toList();
      response = decodeJSON;
    }
    return response;
  }

  /// Get filter by id
  static FilterData? filterById({
    required List<FilterData> filters,
    required String id,
  }) {
    try {
      return filter(filters: filters, strict: true)
          .firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get value from id
  static dynamic valueFromId({
    required List<FilterData> filters,
    required String id,
  }) => filterById(filters: filters, id: id)?.value;

  /// Format data with filters
  /// This function formats data with filters
  static List<Map<String, dynamic>> formatJSON({
    /// Filters to apply
    required List<FilterData> filters,

    /// Data to filter
    required List<Map<String, dynamic>> data,
  }) {
    return data.map((item) {
      Map<String, dynamic> serializedItem = {};
      for (var key in item.keys) {
        var value = item[key];
        final filter = filterById(filters: filters, id: key);
        if (filter == null) {
          serializedItem[key] = value;
        } else if (value is List) {
          serializedItem[key] = value.map((e) {
            return parseValueByInputDataType(
              type: filter.type,
              value: e,
              enums: filter.enums,
            );
          }).toList();
        } else {
          serializedItem[key] = parseValueByInputDataType(
            type: filter.type,
            value: value,
            enums: filter.enums,
          );
        }
      }
      return serializedItem;
    }).toList();
  }

  /// Filter JSON data
  /// This function filters and sorts JSON data based on the filters provided
  static List<Map<String, dynamic>> filterJSON({
    /// Filters to apply
    required List<FilterData> filters,

    /// Data to filter
    required List<Map<String, dynamic>> data,
  }) {
    List<Map<String, dynamic>> response = [];
    final activeOptions = filter(filters: filters);
    if (activeOptions.isEmpty) return data;
    // Map the data to the filter data type
    List<Map<String, dynamic>> formattedData = formatJSON(
      filters: filters,
      data: data,
    );

    /// Sort data
    final sortValue = valueFromId(filters: activeOptions, id: 'sort');
    if (sortValue != null && sortValue is List && sortValue.isNotEmpty) {
      final sortBy = sortValue[0];
      final order = sortValue[1] ?? EnumData.describe(FilterOrder.desc);
      formattedData.sort((a, b) {
        var aValue = a[sortBy];
        var bValue = b[sortBy];
        if (aValue is String && bValue is String) {
          return order == EnumData.describe(FilterOrder.asc)
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        } else if ((aValue is num && bValue is num) ||
            (aValue is double && bValue is double) ||
            (aValue is int && bValue is int)) {
          return order == EnumData.describe(FilterOrder.asc)
              ? (aValue as num).compareTo(bValue as num)
              : (bValue as num).compareTo(aValue as num);
        } else if (aValue is DateTime && bValue is DateTime) {
          return order == EnumData.describe(FilterOrder.asc)
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        } else {
          return order == EnumData.describe(FilterOrder.asc)
              ? aValue.toString().compareTo(bValue.toString())
              : bValue.toString().compareTo(aValue.toString());
        }
      });
    }

    /// Return sorted data when there are no more filters
    if (sortValue != null && activeOptions.length == 1) return formattedData;

    final activeOptionsWithoutSort = activeOptions.where((element) {
      return element.operator != FilterOperator.sort;
    }).toList();
    final activeOptionsWithoutSortLength = activeOptionsWithoutSort.length;
    for (var item in formattedData) {
      int totalMatches = 0;
      for (var filter in activeOptionsWithoutSort) {
        bool matches = false;
        bool compared = false;
        if (filter.operator == FilterOperator.any) {
          matches = true;
          totalMatches++;
          continue;
        }
        final value = item[filter.id];
        if (filter.value == null || value == null) {
          matches = false;
          totalMatches++;
          continue;
        }
        switch (filter.type) {
          case InputDataType.date:
          case InputDataType.dateTime:
          case InputDataType.timestamp:
            if (value is DateTime) {
              switch (filter.operator!) {
                case FilterOperator.whereIn:
                case FilterOperator.contains:
                  compared = true;
                  matches = false;
                  break;
                case FilterOperator.greaterThan:
                  compared = true;
                  if (value.isAfter(filter.value)) matches = true;
                  break;
                case FilterOperator.greaterThanOrEqual:
                  compared = true;
                  if (value.isAtSameMomentAs(filter.value) ||
                      value.isAfter(filter.value)) matches = true;
                  break;
                case FilterOperator.lessThan:
                  compared = true;
                  if (value.isBefore(filter.value)) matches = true;
                  break;
                case FilterOperator.lessThanOrEqual:
                  compared = true;
                  if (value.isAtSameMomentAs(filter.value) ||
                      value.isBefore(filter.value)) matches = true;
                  break;
                case FilterOperator.between:
                  compared = true;
                  if ((value.isAfter(filter.value[0]) ||
                          value.isAtSameMomentAs(filter.value[0])) &&
                      (value.isBefore(filter.value[1]) ||
                          value.isAtSameMomentAs(filter.value[1]))) {
                    matches = true;
                  }
                  break;
                case FilterOperator.any:
                  matches = true;
                  compared = true;
                  break;
                default:
              }
            }
            break;
          default:
            break;
        }

        /// Compare other data types
        if (!compared) {
          switch (filter.operator!) {
            case FilterOperator.sort:
              // Ignore this one, but don't remove it
              break;
            case FilterOperator.equal:
              if (value == filter.value) matches = true;
              break;
            case FilterOperator.notEqual:
              if (value != filter.value) matches = true;
              break;
            case FilterOperator.contains:
              if (value.toString().contains(filter.value)) {
                matches = true;
              }
              break;
            case FilterOperator.greaterThan:
              if (value > filter.value) matches = true;
              break;
            case FilterOperator.lessThan:
              if (value < filter.value) matches = true;
              break;
            case FilterOperator.greaterThanOrEqual:
              if (value >= filter.value) matches = true;
              break;
            case FilterOperator.lessThanOrEqual:
              if (value <= filter.value) matches = true;
              break;
            case FilterOperator.whereIn:
              if (value.toString().contains(filter.value)) {
                matches = true;
              }
              break;
            case FilterOperator.any:
              matches = true;
              break;
            case FilterOperator.between:
              if (value >= filter.value[0] && value <= filter.value[1]) {
                matches = true;
              }
              break;
          }
        }
        if (matches) totalMatches++;
      }
      if (totalMatches == activeOptionsWithoutSortLength) response.add(item);
    }

    return response;
  }
}
