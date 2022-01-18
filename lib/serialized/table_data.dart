import 'package:json_annotation/json_annotation.dart';

part 'table_data.g.dart';

/// [TableData] serialized data
@JsonSerializable(explicitToJson: true)
class TableData {
  @JsonKey(includeIfNull: false)
  List<TableColumnData>? header;
  @JsonKey(disallowNullValue: true)
  final List<TableRowData> rows;
  @JsonKey(includeIfNull: false)
  final List<dynamic>? footer;

  bool active;
  int level;

  TableData({
    this.header,
    this.rows = const [],
    this.footer,
    this.active = false,
    this.level = 0,
  });

  factory TableData.fromJson(Map<String, dynamic>? json) =>
      _$TableDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$TableDataToJson(this);
}

enum TableDataType {
  @JsonValue('string')
  string,
  @JsonValue('number')
  number,
  @JsonValue('decimal')
  decimal,
  @JsonValue('date')
  date,
  @JsonValue('currency')
  currency,
  @JsonValue('path')
  path,
  @JsonValue('link')
  link,
}

@JsonSerializable(explicitToJson: true)
class TableColumnData {
  @JsonKey(disallowNullValue: true)
  String value;
  @JsonKey(disallowNullValue: true)
  String? label;
  @JsonKey(includeIfNull: true, defaultValue: TableDataType.string)
  TableDataType type;
  double? width;

  TableColumnData({
    this.value = '',
    this.type = TableDataType.string,
    this.width,
    this.label,
  });

  factory TableColumnData.fromJson(Map<String, dynamic>? json) =>
      _$TableColumnDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$TableColumnDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class TableRowData {
  @JsonKey(disallowNullValue: true, defaultValue: [])
  final List<dynamic> cells;
  @JsonKey(disallowNullValue: true)
  final TableData? child;
  bool active;

  TableRowData({
    this.cells = const [],
    this.child,
    this.active = false,
  });

  factory TableRowData.fromJson(Map<String, dynamic>? json) =>
      _$TableRowDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$TableRowDataToJson(this);
}
