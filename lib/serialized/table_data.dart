import 'package:json_annotation/json_annotation.dart';

part 'table_data.g.dart';

/// Stores serialized table content and optional nested table state.
///
/// This model is used when tabular data needs to be transported independently of
/// the widget tree while still retaining presentation hints such as expansion
/// state and hierarchy depth.
@JsonSerializable(explicitToJson: true)
class TableData {
  /// Stores the column metadata for the table header.
  @JsonKey(includeIfNull: false)
  List<TableColumnData>? header;

  /// Stores the table rows.
  @JsonKey(disallowNullValue: true)
  final List<TableRowData> rows;

  /// Stores footer cells for summary rows when present.
  @JsonKey(includeIfNull: false)
  final List<dynamic>? footer;

  /// Indicates whether this table or subtree is currently active in the UI.
  bool active;

  /// Stores the nesting level for hierarchical tables.
  int level;

  /// Creates serialized table data.
  TableData({
    this.header,
    this.rows = const [],
    this.footer,
    this.active = false,
    this.level = 0,
  });

  /// Builds [TableData] from serialized JSON.
  ///
  /// A `null` payload is treated as empty input so optional table values can be
  /// recreated with their default collections and flags.
  factory TableData.fromJson(Map<String, dynamic>? json) =>
      _$TableDataFromJson(json ?? {});

  /// Converts this table into JSON.
  Map<String, dynamic> toJson() => _$TableDataToJson(this);
}

/// Enumerates the supported semantic types for table columns.
///
/// The selected type helps renderers choose formatting and interaction behavior
/// without inspecting the raw cell values themselves.
enum TableDataType {
  /// Treats the column as free-form text.
  @JsonValue('string')
  string,

  /// Treats the column as an integer-like numeric value.
  @JsonValue('number')
  number,

  /// Treats the column as a fractional numeric value.
  @JsonValue('decimal')
  decimal,

  /// Treats the column as a date value.
  @JsonValue('date')
  date,

  /// Treats the column as a currency value.
  @JsonValue('currency')
  currency,

  /// Treats the column as a filesystem or routing path.
  @JsonValue('path')
  path,

  /// Treats the column as a navigable link.
  @JsonValue('link')
  link,
}

/// Stores metadata for a single table column.
///
/// Separating column definitions from row data keeps serialized tables easier to
/// evolve as formatting requirements change.
@JsonSerializable(explicitToJson: true)
class TableColumnData {
  /// Stores the underlying column key or value identifier.
  @JsonKey(disallowNullValue: true)
  String value;

  /// Stores the user-facing column label.
  @JsonKey(disallowNullValue: true)
  String? label;

  /// Stores the semantic data type used for formatting.
  @JsonKey(includeIfNull: true)
  TableDataType type;

  /// Stores the preferred column width.
  @JsonKey(includeIfNull: false)
  double width;

  /// Creates serialized column metadata.
  TableColumnData({
    this.value = '',
    this.type = TableDataType.string,
    this.width = 50,
    this.label,
  });

  /// Builds [TableColumnData] from serialized JSON.
  ///
  /// A `null` payload is treated as empty input so missing column metadata can
  /// fall back to safe defaults.
  factory TableColumnData.fromJson(Map<String, dynamic>? json) =>
      _$TableColumnDataFromJson(json ?? {});

  /// Converts this column definition into JSON.
  Map<String, dynamic> toJson() => _$TableColumnDataToJson(this);
}

/// Stores the cells for a single table row.
///
/// Rows can optionally contain a nested [TableData] instance, which allows the
/// serialized model to represent expandable tree tables.
@JsonSerializable(explicitToJson: true)
class TableRowData {
  /// Stores the ordered cell values for the row.
  @JsonKey(disallowNullValue: true)
  final List<dynamic> cells;

  /// Stores a nested table shown when the row is expanded.
  @JsonKey(includeIfNull: false)
  final TableData? child;

  /// Indicates whether the row is currently active in the UI.
  bool active;

  /// Creates serialized row data.
  TableRowData({this.cells = const [], this.child, this.active = false});

  /// Builds [TableRowData] from serialized JSON.
  ///
  /// A `null` payload is treated as empty input so optional row values can still
  /// be deserialized consistently.
  factory TableRowData.fromJson(Map<String, dynamic>? json) =>
      _$TableRowDataFromJson(json ?? {});

  /// Converts this row into JSON.
  Map<String, dynamic> toJson() => _$TableRowDataToJson(this);
}
