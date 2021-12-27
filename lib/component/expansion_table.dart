import 'package:flutter/material.dart';

/// [ExpansionTable]
/// Example:
/// -----------------------
/// ExpansionTable(
///   headingRowColor: Colors.grey.shade50,
///   headingTextStyle: textTheme.subtitle1,
///   options: ExpansionTableOptions(
///     columns: columns,
///     footer: [
///       Text("Total"),
///       Text("footer"),
///       Text("footer"),
///     ],
///     rows: [
///       ExpansionTableRowOptions(
///         cells: [
///           TextButton(onPressed: () {}, child: Text("Group 1")),
///           Text("row 1 - 2"),
///           Text("row 1 - 3"),
///         ],
///         child: ExpansionTableOptions(
///           columns: columns,
///           footer: [
///             Text("Total For Group 1"),
///             Text("footer"),
///             Text("footer"),
///           ],
///           rows: [
///             ExpansionTableRowOptions(
///               cells: [
///                 Text("Child Group 1"),
///                 Text("row child  1 - 2"),
///                 Text("row child  1 - 3"),
///               ],
///               child: ExpansionTableOptions(
///                 columns: columns,
///                 footer: [
///                   Text("Total for Child Group 1"),
///                   Text("footer"),
///                   Text("footer"),
///                 ],
///                 rows: [
///                   ExpansionTableRowOptions(
///                     cells: [
///                       Text("Internal"),
///                       Text("row child 3 - 2"),
///                       Text("row child 3 - 3"),
///                     ],
///                   ),
///                   ExpansionTableRowOptions(
///                     cells: [
///                       Text("row child 3 - 1"),
///                       Text("row child 3 - 2"),
///                       Text("row child 3 - 3"),
///                     ],
///                   ),
///                 ],
///               ),
///             ),
///             ExpansionTableRowOptions(
///               cells: [
///                 Text("row child  2 - 1"),
///                 Text("row child  2 - 2"),
///                 Text("row child  2 - 3"),
///               ],
///               child: ExpansionTableOptions(
///                 columns: columns,
///                 rows: [
///                   ExpansionTableRowOptions(
///                     cells: [
///                       Text("row child 3 - 1"),
///                       Text("row child 3 - 2"),
///                       Text("row child 3 - 3"),
///                     ],
///                   ),
///                   ExpansionTableRowOptions(
///                     cells: [
///                       Text("row child 3 - 1"),
///                       Text("row child 3 - 2"),
///                       Text("row child 3 - 3"),
///                     ],
///                   ),
///                 ],
///               ),
///             ),
///           ],
///         ),
///       ),
///     ],
///   ),
/// )
class ExpansionTable extends StatelessWidget {
  ExpansionTable({
    Key? key,
    required this.options,
    this.headingRowHeight,
    this.headingTextStyle,
    this.decoration,
    this.dataRowColor,
    this.dataRowHeight,
    this.dataTextStyle,
    this.headingRowColor,
    this.horizontalMargin,
    this.columnSpacing,
    this.dividerThickness,
  }) : super(key: key);

  final ExpansionTableOptions options;

  /// {@macro flutter.material.dataTable.decoration}
  final Decoration? decoration;

  /// {@macro flutter.material.dataTable.dataRowColor}
  /// {@macro flutter.material.DataTable.dataRowColor}
  final MaterialStateProperty<Color?>? dataRowColor;

  /// {@macro flutter.material.dataTable.dataRowHeight}
  final double? dataRowHeight;

  /// {@macro flutter.material.dataTable.dataTextStyle}
  final TextStyle? dataTextStyle;

  /// {@macro flutter.material.dataTable.headingRowColor}
  /// {@macro flutter.material.DataTable.headingRowColor}
  final Color? headingRowColor;

  /// {@macro flutter.material.dataTable.headingRowHeight}
  final double? headingRowHeight;

  /// {@macro flutter.material.dataTable.headingTextStyle}
  final TextStyle? headingTextStyle;

  /// {@macro flutter.material.dataTable.horizontalMargin}
  final double? horizontalMargin;

  /// {@macro flutter.material.dataTable.columnSpacing}
  final double? columnSpacing;

  /// {@macro flutter.material.dataTable.dividerThickness}
  final double? dividerThickness;

  @override
  Widget build(BuildContext context) {
    ScrollController _controller = ScrollController();
    ScrollController _controllerHorizontal = ScrollController();
    List<DataColumn> _columns =
        options.columns.map((e) => DataColumn(label: e)).toList();
    List<ExpansionTableRowWidget> _rows = options.rows.map((e) {
      ExpansionTableRowOptions row = e;
      row.columns = options.columns;
      row.level = options.level;
      return ExpansionTableRowWidget(options: row);
    }).toList();
    if (options.footer != null) {
      _rows.add(ExpansionTableRowWidget(
        options: ExpansionTableRowOptions(
          cells: options.footer!,
          columns: options.columns,
          level: options.level > 0 ? options.level - 1 : 0,
        ),
      ));
    }
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    Widget rows = Flex(
      direction: Axis.vertical,
      children: _rows,
    );
    final ThemeData themeData = Theme.of(context);

    double _headingRowHeight =
        headingRowHeight ?? themeData.dataTableTheme.headingRowHeight ?? 56;
    Widget columns = Material(
      elevation: 1,
      color: headingRowColor,
      child: DataTable(
        headingRowHeight:
            headingRowHeight ?? themeData.dataTableTheme.headingRowHeight,
        columns: _columns,
        rows: [],
        headingTextStyle: headingTextStyle,
        dividerThickness: dividerThickness,
        horizontalMargin: horizontalMargin,
      ),
    );
    if (options.level > 0) {
      return rows;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: Scrollbar(
        isAlwaysShown: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        showTrackOnHover: true,
        interactive: true,
        controller: _controllerHorizontal,
        child: SingleChildScrollView(
          controller: _controllerHorizontal,
          scrollDirection: Axis.horizontal,
          primary: false,
          child: Flex(
            direction: Axis.vertical,
            children: [
              columns,
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: height - _headingRowHeight),
                child: Scrollbar(
                  isAlwaysShown: true,
                  scrollbarOrientation: ScrollbarOrientation.right,
                  showTrackOnHover: true,
                  interactive: true,
                  controller: _controller,
                  child: SingleChildScrollView(
                    primary: false,
                    controller: _controller,
                    scrollDirection: Axis.vertical,
                    child: rows,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [ExpansionTableRowWidget]
class ExpansionTableRowWidget extends StatefulWidget {
  const ExpansionTableRowWidget({
    Key? key,
    required this.options,
    this.decoration,
    this.dataRowColor,
    this.dataRowHeight,
    this.dataTextStyle,
    this.headingRowColor,
    this.horizontalMargin,
    this.dividerThickness,
  }) : super(key: key);

  final ExpansionTableRowOptions options;

  /// {@macro flutter.material.dataTable.decoration}
  final Decoration? decoration;

  /// {@macro flutter.material.dataTable.dataRowColor}
  /// {@macro flutter.material.DataTable.dataRowColor}
  final MaterialStateProperty<Color?>? dataRowColor;

  /// {@macro flutter.material.dataTable.dataRowHeight}
  final double? dataRowHeight;

  /// {@macro flutter.material.dataTable.dataTextStyle}
  final TextStyle? dataTextStyle;

  /// {@macro flutter.material.dataTable.headingRowColor}
  /// {@macro flutter.material.DataTable.headingRowColor}
  final MaterialStateProperty<Color?>? headingRowColor;

  /// {@macro flutter.material.dataTable.horizontalMargin}
  final double? horizontalMargin;

  /// {@macro flutter.material.dataTable.dividerThickness}
  final double? dividerThickness;

  @override
  State<ExpansionTableRowWidget> createState() =>
      _ExpansionTableRowWidgetState();
}

class _ExpansionTableRowWidgetState extends State<ExpansionTableRowWidget> {
  @override
  Widget build(BuildContext context) {
    List<DataColumn> _columns =
        widget.options.columns!.map((e) => DataColumn(label: e)).toList();
    List<Widget> _cellsBase = [...widget.options.cells];
    double _childLeftSpace = 0;
    _childLeftSpace = widget.options.level.toDouble() * 16;
    // kMinInteractiveDimension
    double iconContentSize = 40;
    _childLeftSpace += iconContentSize + _childLeftSpace;

    _cellsBase[0] = Flex(
      direction: Axis.horizontal,
      children: [
        SizedBox(
          width: _childLeftSpace,
          child: widget.options.child != null
              ? IconButton(
                  constraints: BoxConstraints(
                    minHeight: iconContentSize,
                    minWidth: iconContentSize,
                  ),
                  onPressed: () {
                    widget.options.child?.rows
                        .forEach((e) => e.expanded = false);
                    widget.options.expanded = !widget.options.expanded;
                    if (mounted) setState(() {});
                  },
                  icon: Icon(
                    widget.options.expanded
                        ? Icons.arrow_drop_down
                        : Icons.arrow_right,
                  ),
                )
              : null,
        ),
        widget.options.cells[0]
      ],
    );

    List<DataCell> _cells = _cellsBase.map((e) => DataCell(e)).toList();
    List<Widget> content = [];
    content.add(DataTable(
      headingRowHeight: 0,
      columns: _columns,
      rows: [DataRow(cells: _cells)],
      dataRowColor: widget.dataRowColor,
      dataRowHeight: widget.dataRowHeight,
      dataTextStyle: widget.dataTextStyle,
      dividerThickness: widget.dividerThickness,
      horizontalMargin: widget.horizontalMargin,
    ));

    if (widget.options.child != null && widget.options.expanded) {
      widget.options.child?.level =
          widget.options.level == 0 ? 1 : widget.options.level + 1;
      content.add(ExpansionTable(
        options: widget.options.child!,
      ));
      content.add(SizedBox(height: 32));
    }
    return Flex(
      direction: Axis.vertical,
      children: content,
    );
  }
}

/// [ExpansionTableOptions] defines base options for a [ExpansionTable]
class ExpansionTableOptions {
  final List<Widget> columns;
  int level;
  final List<ExpansionTableRowOptions> rows;
  final List<Widget>? footer;

  ExpansionTableOptions({
    this.columns = const [],
    this.rows = const [],
    this.footer,
    this.level = 0,
  });
}

/// [ExpansionTableRowOptions] Defines base options for a [ExpansionTableRowWidget]
class ExpansionTableFooterOptions {
  final List<Widget> cells;
  List<Widget>? columns;
  int level;

  ExpansionTableFooterOptions({
    this.cells = const [],
    this.columns = const [],
    this.level = 0,
  });
}

/// [ExpansionTableRowOptions] Defines base options for a [ExpansionTableRowWidget]
class ExpansionTableRowOptions {
  final List<Widget> cells;
  List<Widget>? columns;
  final List<Widget>? footer;
  final ExpansionTableOptions? child;
  bool expanded;
  int level;

  ExpansionTableRowOptions({
    this.cells = const [],
    this.columns = const [],
    this.footer,
    this.expanded = false,
    this.child,
    this.level = 0,
  });
}
