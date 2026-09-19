import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../component/input_data.dart';
import '../serialized/filter_data.dart';
import 'enum_data.dart';
import 'log_color.dart';

/// Identifies the query dialect used when serializing filters.
enum SQLQueryType { sql, openSearch, bigQuery }

/// Formats a [DateTime] as a `yyyy-MM-dd` date string for date filters.
///
/// Hoisted to file scope so [FilterHelper.valueFromType] reuses one formatter
/// instead of constructing a new [DateFormat] on every date value it serializes.
final DateFormat _filterDateFormat = DateFormat('yyyy-MM-dd');

/// Transforms [FilterData] objects into query strings, JSON, and in-memory filters.
///
/// This helper is shared by state and data layers that need to serialize the same
/// filter definitions for different backends or apply them to local collections.
class FilterHelper {
  /// Caps the encoded payload length accepted by [decode].
  ///
  /// The payload arrives as a query parameter, so an unbounded input would let
  /// a caller force an arbitrarily large base64 and JSON parse before any
  /// shape check could reject it.
  static const int _maxEncodedLength = 64 * 1024;

  /// Caps how many entries [decode] materializes from a single payload.
  ///
  /// Bounds the work done for a syntactically valid but abusive payload. The
  /// limit sits far above any realistic filter editor, so legitimate callers
  /// never reach it.
  static const int _maxFilterEntries = 200;

  /// Converts [value] into a backend-friendly literal for [dataType].
  ///
  /// Dates and timestamps are normalized to UTC to avoid locale-dependent query
  /// results, and the returned representation is adjusted for [sqlQueryType]
  /// when a backend expects wrapper functions such as `DATE(...)`.
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
        final endDateFormatted = DateTime.utc(
          baseDate.year,
          baseDate.month,
          baseDate.day,
        );
        final formatted = _filterDateFormat.format(endDateFormatted);
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

  /// Returns the operator fragment used for [operator] in [sqlQueryType].
  ///
  /// Some operators, such as `contains`, expand into backend-specific query
  /// syntax instead of a single symbol, so this private helper keeps those
  /// differences isolated from the main query builder.
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

  /// Builds a query for [table] from the active entries in [filterData].
  ///
  /// Empty or inactive filters are ignored, sorting is appended when present,
  /// and `null` is returned when there is nothing meaningful to query. The
  /// generated statement varies slightly by [sqlQueryType] so the same filter set
  /// can target multiple storage engines.
  static String? toSQL({
    required String table,
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

  /// Encodes the query generated by [toSQL] as a base64 string.
  ///
  /// This is useful when queries need to travel through URLs or storage layers
  /// that expect opaque text payloads instead of raw SQL.
  static String? toSQLEncoded({
    required String table,
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

  /// Returns the first value seen for each filter id in [filterData].
  ///
  /// Duplicate ids are ignored after their initial occurrence, which mirrors how
  /// merge and lookup operations in this helper treat filter identity.
  static Map<String, dynamic> filterIdsValue(List<FilterData> filterData) {
    Map<String, dynamic> data = {};
    for (int i = 0; i < filterData.length; i++) {
      final item = filterData[i];
      data.putIfAbsent(item.id, () => item.value);
    }
    return data;
  }

  /// Merges incoming filter values into [filters] and returns the updated list.
  ///
  /// Existing filters keep their position in the original list, while unseen ids
  /// are appended. When a merged filter has no operator, its value state is
  /// cleared so downstream consumers treat it as inactive.
  static List<FilterData> merge({
    required List<FilterData> filters,
    required List<FilterData> merge,
  }) {
    List<FilterData> filterDataUpdated = [...filters];
    for (int i = 0; i < merge.length; i++) {
      FilterData toMerge = merge[i];

      /// Add filter if doesn't exists
      bool filterExists = filters
          .where((element) => element.id == toMerge.id)
          .isNotEmpty;
      if (!filterExists) {
        filterDataUpdated.add(toMerge);
      }

      /// Update existing filter
      FilterData item = filterDataUpdated.firstWhere(
        (element) => element.id == toMerge.id,
      );
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

  /// Returns only filters that are currently active.
  ///
  /// When [strict] is `true`, [FilterOperator.any] entries are also excluded so
  /// callers can look up concrete constraints without placeholder filters.
  static List<FilterData> filter({
    required List<FilterData> filters,
    bool strict = false,
  }) {
    return filters
        .where(
          (element) =>
              // element.value != null &&
              element.operator != null &&
              (strict ? element.operator != FilterOperator.any : true),
        )
        .toList();
  }

  /// Serializes [filters] with non-null values into JSON maps.
  ///
  /// This keeps payloads compact by dropping empty filter shells before they are
  /// sent over the network or stored locally.
  static List<Map<String, dynamic>> toJSON(List<FilterData> filters) {
    return filters
        .where((element) => element.value != null)
        .map((e) => e.toJson())
        .toList();
  }

  /// Deserializes [filters] produced by [toJSON] back into [FilterData] objects.
  static List<FilterData> fromJSON(List<dynamic> filters) {
    return filters
        .map((e) => FilterData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Whether [filterData] describes a concrete constraint worth encoding.
  ///
  /// This is the single statement of the wire-inclusion rule, kept deliberately
  /// independent of [filter] so that a future UI-motivated change to the
  /// on-screen filtering cannot silently alter the encoded payload.
  ///
  /// A row is excluded unless it carries both an operator and a value. Partially
  /// configured rows are a normal intermediate UI state — a user picks a field
  /// and an operator before typing a value — and they describe no constraint, so
  /// encoding them would ask a consumer to narrow a query by nothing.
  /// [FilterOperator.any] is excluded for the same reason: it is a placeholder
  /// that matches everything.
  ///
  /// When [includeSort] is `false`, [FilterOperator.sort] rows are excluded as
  /// well. A sort directive describes ordering rather than a constraint, so a
  /// consumer that receives ordering through its own dedicated parameter has no
  /// field to match it against. The test is deliberately the operator alone,
  /// mirroring [filterData], so a genuine constraint on a field that happens to
  /// be named `sort` is still encoded.
  static bool _isEncodable(FilterData filterData, {required bool includeSort}) {
    if (filterData.operator == null) return false;
    if (filterData.operator == FilterOperator.any) return false;
    if (!includeSort && filterData.operator == FilterOperator.sort) {
      return false;
    }
    final value = filterData.value;
    if (value == null) return false;
    if (value is String && value.isEmpty) return false;
    return true;
  }

  /// Encodes active [filters] as a base64 JSON string.
  ///
  /// Only rows satisfying [_isEncodable] are included, so the payload matches
  /// what [toJSON] would keep and round-trips losslessly through [decode].
  ///
  /// Returning `null` for an empty active filter set makes it easy for callers to
  /// omit query parameters entirely instead of sending empty payloads.
  ///
  /// [includeSort] defaults to `true`, which keeps sort directives inside the
  /// payload so an encoded value round-trips the complete on-screen state
  /// through [decode]. Pass `false` when the payload is bound for a consumer
  /// that receives ordering through its own parameter; the remaining entries
  /// keep their original `index`, so excluding a sort row may leave a gap rather
  /// than renumbering the rows around it.
  static String? encode(List<FilterData> filters, {bool includeSort = true}) {
    try {
      final filterDataValid = toJSON(
        filters
            .where((element) => _isEncodable(element, includeSort: includeSort))
            .toList(),
      );
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

  /// Decodes a base64 JSON [filters] payload into [FilterData] objects.
  ///
  /// The payload is untrusted: it travels as a query parameter and can be
  /// edited, truncated, or replaced by whoever issues the request. Every
  /// failure mode therefore degrades to a value rather than an exception, so a
  /// hostile or corrupt payload cannot throw out of a published API and into a
  /// caller that has no reasonable way to recover.
  ///
  /// A `null` input yields an empty list so callers can treat absent filter state
  /// and unparseable optional query parameters uniformly. A payload that is not
  /// base64, not JSON, or whose root is not a list also yields an empty list.
  /// Individual entries that fail to deserialize are skipped so one bad element
  /// does not discard the filters that decoded correctly.
  static List<FilterData> decode(String? filters) {
    if (filters == null || filters.isEmpty) return [];
    if (filters.length > _maxEncodedLength) {
      debugPrint(
        LogColor.error(
          'FilterHelper.decode: payload exceeds $_maxEncodedLength characters',
        ),
      );
      return [];
    }
    late final List<dynamic> entries;
    try {
      Codec<String, dynamic> stringToBase64 = utf8.fuse(base64);
      final decoded = json.decode(stringToBase64.decode(filters));
      if (decoded is! List) {
        debugPrint(LogColor.error('FilterHelper.decode: root is not a list'));
        return [];
      }
      entries = decoded;
    } catch (e) {
      debugPrint(LogColor.error('FilterHelper.decode: $e'));
      return [];
    }
    final response = <FilterData>[];
    for (final entry in entries.take(_maxFilterEntries)) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        response.add(FilterData.fromJson(entry));
      } catch (e) {
        debugPrint(LogColor.error('FilterHelper.decode entry: $e'));
      }
    }
    return response;
  }

  /// Returns the active filter whose id matches [id], if one exists.
  ///
  /// The lookup uses [filter] in strict mode so placeholder `any` filters do not
  /// masquerade as real values.
  static FilterData? filterById({
    required List<FilterData> filters,
    required String id,
  }) {
    try {
      return filter(
        filters: filters,
        strict: true,
      ).firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Returns the current value for the active filter identified by [id].
  static dynamic valueFromId({
    required List<FilterData> filters,
    required String id,
  }) => filterById(filters: filters, id: id)?.value;

  /// Normalizes [data] values according to the matching definitions in [filters].
  ///
  /// This prepares raw JSON-like maps for reliable comparison by converting each
  /// value through [parseValueByInputDataType] before filtering or sorting.
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

  /// Filters and sorts in-memory [data] using the active [filters].
  ///
  /// This mirrors the behavior of [toSQL] for local collections, which is useful
  /// when previewing results client-side or working with data that never reaches
  /// a query backend. Sorting is applied before filtering so callers receive the
  /// final display order in one pass.
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
                      value.isAfter(filter.value)) {
                    matches = true;
                  }
                  break;
                case FilterOperator.lessThan:
                  compared = true;
                  if (value.isBefore(filter.value)) matches = true;
                  break;
                case FilterOperator.lessThanOrEqual:
                  compared = true;
                  if (value.isAtSameMomentAs(filter.value) ||
                      value.isBefore(filter.value)) {
                    matches = true;
                  }
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
