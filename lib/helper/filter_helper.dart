import 'dart:convert';

import 'package:intl/intl.dart';

import '../component/input_data.dart';
import '../serialized/filter_data.dart';
import 'enum_data.dart';

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
          switch (value.runtimeType) {
            case String:
              response = '"$value"';
              break;
            default:
              response = value;
          }
        }
        break;
      case InputDataType.double:
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
          final value1 = valueFromType(
            sqlQueryType: sqlQueryType,
            dataType: filter.type,
            value: filter.value[0],
          );
          final value2 = valueFromType(
            sqlQueryType: sqlQueryType,
            dataType: filter.type,
            value: filter.value[1],
          );
          subQuery += '${filter.id} >= $value1';
          subQuery += ' and ';
          subQuery += '${filter.id} <= $value2';
          break;
        case FilterOperator.any:
          subQuery +=
              '${filter.id} ${_sqlOperator(operator: filter.operator!, sqlQueryType: sqlQueryType)}';
          break;
        case FilterOperator.sort:
          if (filter.value == null ||
              filter.value == true ||
              filter.value[0] == null ||
              filter.value[1] == null) {
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
    if (sort.isEmpty) {
      sort = 'ORDER BY id ${EnumData.describe(FilterOrder.desc)}';
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
    final filterDataValid = filter(filters: filters);
    if (filterDataValid.isEmpty) return null;
    dynamic jsonParsed = json.encode(filterDataValid);
    final filterString = jsonParsed.toString();
    Codec<String, dynamic> stringToBase64 = utf8.fuse(base64);

    /// Encode
    return stringToBase64.encode(filterString);
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
