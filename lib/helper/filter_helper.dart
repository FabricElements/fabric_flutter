import '../component/input_data.dart';
import '../serialized/filter_data.dart';
import 'enum_data.dart';

class FilterHelper {
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
      case InputDataType.double:
      case InputDataType.url:
      case InputDataType.dropdown:
      case InputDataType.radio:
        response = '"$value"';
        break;
      case InputDataType.int:
        response = value;
        break;
      case InputDataType.enums:
        response = '"${EnumData.describe(value)}"';
        break;
    }
    return response;
  }

  static String queryToSQL({
    required table,
    required List<FilterData> filterData,
    int? limit,
  }) {
    String query = 'select * from $table';
    int count = 0;
    for (int i = 0; i < filterData.length; i++) {
      FilterData filter = filterData[i];
      if (filter.value == null) continue;
      if (filter.operator == null || filter.operator == FilterOperator.any) {
        continue;
      }
      final filterObject = filter.toJson();
      String subQuery = '';
      switch (filter.operator!) {
        case FilterOperator.equal:
          final value = valueFromType(
            dataType: filter.type,
            value: filterObject['value'],
          );
          subQuery += '${filter.id} = $value';
          break;
        case FilterOperator.notEqual:
          final value = valueFromType(
            dataType: filter.type,
            value: filterObject['value'],
          );
          subQuery += '${filter.id} != $value';
          break;
        case FilterOperator.contains:
          // TODO: Handle this case.
          final value = valueFromType(
            dataType: filter.type,
            value: filterObject['value'],
          );
          subQuery += '${filter.id} = $value';
          break;
        case FilterOperator.greaterThan:
          final value = valueFromType(
            dataType: filter.type,
            value: filterObject['value'],
          );
          subQuery += '${filter.id} >= $value';
          break;
        case FilterOperator.lessThan:
          final value = valueFromType(
            dataType: filter.type,
            value: filterObject['value'],
          );
          subQuery += '${filter.id} <= $value';
          break;
        case FilterOperator.between:
          final value1 = valueFromType(
            dataType: filter.type,
            value: filterObject['value'][0],
          );
          final value2 = valueFromType(
            dataType: filter.type,
            value: filterObject['value'][1],
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
}
