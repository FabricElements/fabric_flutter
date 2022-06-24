import 'package:fabric_flutter/serialized/table_data.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic data = {
  'header': [
    {'label': 'Column 1', 'value': 'column1'}
  ]
};

void main() {
  test('Serialize data', () {
    final serialized = TableData.fromJson(data);
    expect(serialized.header!.length, 1, reason: 'Header size is incorrect');
  });

  test('Deserialize data', () {
    final serialized = TableData.fromJson(data);
    final deserialized = serialized.toJson();
    expect(data['header'][0]['value'], deserialized['header'][0]['value'],
        reason: 'Value don\'t match');
  });
}
