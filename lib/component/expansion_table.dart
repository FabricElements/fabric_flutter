import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helper/format_data.dart';
import '../serialized/table_data.dart';

/// [ExpansionTable]
/// Example:
/// -----------------------
class ExpansionTable extends StatefulWidget {
  ExpansionTable({
    Key? key,
    required this.data,
    this.headingRowHeight,
    this.headingTextStyle,
    this.decoration,
    this.dataRowColor,
    this.dataFooterColor,
    this.dataRowHeight,
    this.dataTextStyle,
    this.headingRowColor,
    this.horizontalMargin,
    this.columnSpacing,
    this.dividerThickness,
    this.border,
  })  : assert(data == null || data.header!.length > 0),
        super(key: key);

  final TableData? data;

  /// {@macro flutter.material.dataTable.decoration}
  final Decoration? decoration;

  /// {@macro flutter.material.dataTable.dataRowColor}
  /// {@macro flutter.material.DataTable.dataRowColor}
  final Color? dataFooterColor;

  /// {@macro flutter.material.dataTable.dataRowColor}
  /// {@macro flutter.material.DataTable.dataRowColor}
  final Color? dataRowColor;

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

  /// If null, [DataTableThemeData.columnSpacing] is used. This value defaults
  /// to 56.0 to adhere to the Material Design specifications.
  /// {@macro flutter.material.dataTable.columnSpacing}
  final double? columnSpacing;

  /// {@macro flutter.material.dataTable.dividerThickness}
  final double? dividerThickness;

  /// The style to use when painting the boundary and interior divisions of the table.
  final TableBorder? border;

  @override
  State<ExpansionTable> createState() => _ExpansionTableState();
}

double _widthColumn = 350; // default: 100

// class _NullTableColumnWidth extends TableColumnWidth {
//   const _NullTableColumnWidth();
//
//   @override
//   double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) => throw UnimplementedError();
//
//   @override
//   double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) => throw UnimplementedError();
// }

class _ExpansionTableState extends State<ExpansionTable> {
  @override
  Widget build(BuildContext context) {
    if (widget.data == null) return SizedBox();
    TableData data = widget.data!;
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    final BorderSide borderSide = Divider.createBorderSide(
      context,
      width:
          widget.dividerThickness ?? theme.dataTableTheme.dividerThickness ?? 1,
    );
    // final Border? border = widget.showBottomBorder
    //     ? Border(bottom: borderSide)
    //     : index == 0 ? null : Border(top: borderSide);
    ScrollController _controllerHorizontal = ScrollController();
    ScrollController _controllerVertical = ScrollController();

    // List<Widget> _columns = _getColumns(columns: data.header!);
    // final List<TableColumnWidth> tableColumns = List<TableColumnWidth>.filled(data.header!.length + (displayCheckboxColumn ? 1 : 0), const _NullTableColumnWidth());
    final List<TableColumnWidth> tableColumns = List<TableColumnWidth>.filled(
        data.header!.length, FixedColumnWidth(300.0));
    final double effectiveHorizontalMargin =
        widget.horizontalMargin ?? theme.dataTableTheme.horizontalMargin ?? 0;
    final double effectiveColumnSpacing =
        widget.columnSpacing ?? theme.dataTableTheme.columnSpacing ?? 56;
    final double cellHorizontalPadding = effectiveColumnSpacing / 2;

    List<Widget> _columns = List.generate(data.header!.length, (index) {
      final _column = data.header![index];
      // double _paddingLeft = index > 0 ? effectiveColumnSpacing / 2 : effectiveColumnSpacing;
      // double _paddingRight =
      //     index < data.header!.length ? effectiveColumnSpacing / 2 : effectiveColumnSpacing;
      return ClipRect(
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: _widthColumn,
            minWidth: _widthColumn,
          ),
          // color: Colors.orange,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              // color: Colors.blueGrey,
              padding: EdgeInsets.only(
                left: cellHorizontalPadding,
                right: cellHorizontalPadding,
              ),
              child: Text(
                _column.value,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ),
      );
    });

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double width = constraints.maxWidth.floorToDouble();
        double height = constraints.maxHeight.floorToDouble();

        /// Get the rows
        Widget getRows(
            {required TableRowData row,
            int rowIndex = 0,
            bool isFooter = false}) {
          List<Widget> _cellsBase = List.generate(row.cells.length, (index) {
            final cellValue = row.cells[index];
            final _columnData = data.header![index];
            Widget _baseCell = Container();
            if (cellValue == null) {
              _baseCell = Text('-');
            } else {
              switch (_columnData.type) {
                case TableDataType.string:
                  _baseCell = Text(cellValue.toString());
                  break;
                case TableDataType.currency:
                  _baseCell = Text(FormatData.currencyFormat()
                      .format(double.parse(cellValue.toString())));
                  break;
                case TableDataType.number:
                  _baseCell = Text(FormatData.numberClearFormat()
                      .format(double.parse(cellValue.toString())));
                  break;
                case TableDataType.decimal:
                  _baseCell = Text(FormatData.numberFormat()
                      .format(double.parse(cellValue.toString())));
                  break;
                case TableDataType.path:
                  _baseCell = TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(cellValue);
                      },
                      child: Text('open'));
                  break;
                case TableDataType.link:
                  _baseCell = TextButton(
                      onPressed: () async {
                        await launch(cellValue);
                      },
                      child: Text('open'));
                  break;
                default:
                  _baseCell = Text(cellValue.toString());
              }

              /// Format correct cell value
              // _baseCell = Text(cellValue.toString());
            }
            // double _paddingLeft = index > 0 ? effectiveColumnSpacing / 2 : 0;
            // double _paddingRight = index < data.header!.length
            //     ? effectiveColumnSpacing / 2
            //     : 0;
            if (index == 0) {
              double _childLeftSpace = 0;
              _childLeftSpace = (data.level.toDouble()) * 16;
              double iconContentSize = 40;
              _childLeftSpace += iconContentSize;
              _baseCell = Row(
                children: [
                  SizedBox(
                    width: _childLeftSpace,
                    child: row.child != null
                        ? IconButton(
                            constraints: BoxConstraints(
                              minHeight: iconContentSize,
                              minWidth: iconContentSize,
                            ),
                            splashRadius: 16,
                            onPressed: () {
                              if (row.active) {
                                row.child?.rows
                                    .where((element) => element.active)
                                    .forEach((e) => e.active = false);
                              }
                              row.active = !row.active;
                              if (mounted) setState(() {});
                            },
                            icon: Icon(
                              row.active
                                  ? Icons.arrow_drop_down
                                  : Icons.arrow_right,
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: ClipRect(
                      clipBehavior: Clip.antiAlias,
                      child: _baseCell,
                    ),
                  ),
                ],
              );
            }
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  top: widget.border?.top ?? BorderSide.none,
                  right: widget.border?.right ?? BorderSide.none,
                  bottom: widget.border?.bottom ?? BorderSide.none,
                  left: widget.border?.left ?? BorderSide.none,
                ),
              ),
              child: ClipRect(
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _widthColumn,
                    minWidth: _widthColumn,
                    minHeight: widget.dataRowHeight ??
                        theme.dataTableTheme.dataRowHeight ??
                        30,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      // color: Colors.green,
                      padding: EdgeInsets.only(
                        left: cellHorizontalPadding,
                        right: cellHorizontalPadding,
                      ),
                      child: _baseCell,
                    ),
                  ),
                ),
              ),
            );
          });
          final Border? border = Border(top: borderSide);
          List<Widget> content = [];
          bool _rowDarker = rowIndex.isEven;
          if (data.level.isEven) _rowDarker = !_rowDarker;
          double _rowOpacity = 0;
          _rowOpacity = _rowDarker ? 0.5 : 0;
          Color dataRowColor = widget.dataRowColor ?? Colors.grey.shade50;
          dataRowColor = dataRowColor.withOpacity(_rowOpacity);
          Color rowColor = !isFooter
              ? dataRowColor
              : widget.dataFooterColor ?? Colors.transparent;
          // DataTable
          TextStyle? _dataTextStyle =
              widget.dataTextStyle ?? textTheme.bodyText1;
          Widget rowWidget = Material(
            textStyle:
                widget.dataTextStyle ?? theme.dataTableTheme.dataTextStyle,
            color: rowColor,
            child: Container(
              constraints: BoxConstraints(
                minHeight: widget.dataRowHeight ??
                    theme.dataTableTheme.dataRowHeight ??
                    30,
              ),
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: tableColumns.asMap(),
                children: [
                  TableRow(
                    children: _cellsBase,
                  )
                ],
              ),
            ),
          );
          content.add(rowWidget);
          if (row.child != null && row.active) {
            // TableData childData = row.child!;
            row.child!.active = false;
            row.child!.level = (data.level) + 1;
            row.child!.header = data.header;
            content.add(ExpansionTable(
              data: row.child!,
            ));
            content.add(SizedBox(height: 32));
          }
          return Container(
            decoration: BoxDecoration(
              border: border,
            ),
            child: Flex(
              direction: Axis.vertical,
              children: content,
            ),
          );
        }

        List<Widget> _rows = List.generate(
          data.rows.length,
          (index) => getRows(row: data.rows[index], rowIndex: index),
        );

        if (data.footer != null) {
          TableRowData footer = TableRowData(
            cells: data.footer!,
          );
          _rows.add(getRows(row: footer, isFooter: true));
        }

        Widget rows = Flex(
          direction: Axis.vertical,
          children: _rows,
        );

        double _headingRowHeight = widget.headingRowHeight ??
            theme.dataTableTheme.headingRowHeight ??
            56;
        double totalWidth =
            (data.header!.length * 300) + effectiveHorizontalMargin;
        Widget columns = Material(
          elevation: 1,
          textStyle:
              widget.headingTextStyle ?? theme.dataTableTheme.headingTextStyle,
          color: widget.headingRowColor ?? Colors.grey.shade100,
          child: Container(
            padding:
                EdgeInsets.symmetric(horizontal: effectiveHorizontalMargin),
            alignment: Alignment.center,
            height: _headingRowHeight,
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: tableColumns.asMap(),
              children: [TableRow(children: _columns)],
            ),
          ),
        );
        if (data.level > 0) {
          return rows;
        }
        return ConstrainedBox(
          constraints: BoxConstraints(
              minHeight: height,
              minWidth: width,
              maxHeight: height,
              maxWidth: width),
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: totalWidth,
                  minWidth: width,
                  minHeight: height,
                  maxHeight: height,
                ),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  // direction: Axis.vertical,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: height - _headingRowHeight,
                        maxWidth: totalWidth,
                        minWidth: totalWidth,
                      ),
                      child: Scrollbar(
                        isAlwaysShown: true,
                        scrollbarOrientation: ScrollbarOrientation.right,
                        showTrackOnHover: true,
                        interactive: true,
                        controller: _controllerVertical,
                        child: ListView(
                          controller: _controllerVertical,
                          primary: false,
                          children: _rows,
                        ),
                      ),
                    ),
                    Positioned(child: columns, top: 0, left: 0, right: 0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
