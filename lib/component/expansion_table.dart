import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helper/format_data.dart';
import '../serialized/table_data.dart';

/// Renders hierarchical [TableData] with expandable child rows.
///
/// The widget mirrors the visual language of [DataTable] while supporting nested
/// tables inside rows. Root tables add horizontal scrolling and headers, while
/// child tables inherit the header definition so expanded content stays aligned
/// with its parent columns.
///
/// Example:
/// -----------------------
class ExpansionTable extends StatefulWidget {
  /// Creates an [ExpansionTable] for the provided [data].
  ///
  /// When [data] is non-null, its header must contain at least one column so the
  /// widget can size rows and render nested descendants consistently.
  ExpansionTable({
    super.key,
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
  }) : assert(data == null || data.header!.isNotEmpty);

  /// Supplies the hierarchical table model rendered by this widget.
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

  /// Creates the mutable expansion state for [ExpansionTable].
  @override
  State<ExpansionTable> createState() => _ExpansionTableState();
}

/// Stores the fixed width assigned to each column so nested tables stay aligned.
double _widthColumn = 350; // default: 100

/// Holds the recursive row-building logic for [ExpansionTable].
class _ExpansionTableState extends State<ExpansionTable> {
  /// Builds the current table level and, when expanded, any child table levels.
  ///
  /// Root tables render headers and horizontal scrolling, while nested tables
  /// return only their rows so expanded content can appear inline beneath the
  /// parent row that revealed it.
  @override
  Widget build(BuildContext context) {
    if (widget.data == null) return const SizedBox();
    TableData data = widget.data!;
    final theme = Theme.of(context);
    // Define MaterialState
    Set<WidgetState> states = <WidgetState>{};
    // final textTheme = theme.textTheme;
    final BorderSide borderSide = Divider.createBorderSide(
      context,
      width:
          widget.dividerThickness ?? theme.dataTableTheme.dividerThickness ?? 1,
    );
    ScrollController controllerHorizontal = ScrollController();
    final List<TableColumnWidth> tableColumns = List<TableColumnWidth>.filled(
      data.header!.length,
      const FixedColumnWidth(300.0),
    );
    final double effectiveHorizontalMargin =
        widget.horizontalMargin ?? theme.dataTableTheme.horizontalMargin ?? 0;
    final double effectiveColumnSpacing =
        widget.columnSpacing ?? theme.dataTableTheme.columnSpacing ?? 56;
    final double cellHorizontalPadding = effectiveColumnSpacing / 2;

    List<Widget> columnsList = List.generate(data.header!.length, (index) {
      final column = data.header![index];
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
                column.value,
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
        // double width = constraints.maxWidth.floorToDouble();
        // double height = constraints.maxHeight.floorToDouble();

        /// Builds the widgets for a single row and any expanded descendants.
        ///
        /// The helper applies per-column formatting, renders hierarchical
        /// indentation in the first cell, and recursively inserts child tables
        /// when the row is expanded.
        Widget getRows({
          required TableRowData row,
          int rowIndex = 0,
          bool isFooter = false,
        }) {
          List<Widget> cellsBase = List.generate(row.cells.length, (index) {
            dynamic cellValue = row.cells[index];
            final columnData = data.header![index];
            Widget baseCell = Container();
            if (cellValue == null) {
              baseCell = const Text('-');
            } else {
              switch (columnData.type) {
                case TableDataType.string:
                  baseCell = Text(cellValue.toString());
                  break;
                case TableDataType.currency:
                  baseCell = Text(
                    FormatData.currencyFormat().format(
                      num.parse(cellValue.toString()),
                    ),
                  );
                  break;
                case TableDataType.number:
                  baseCell = Text(
                    FormatData.numberClearFormat().format(
                      num.parse(cellValue.toString()),
                    ),
                  );
                  break;
                case TableDataType.decimal:
                  baseCell = Text(
                    FormatData.numberFormat().format(
                      num.parse(cellValue.toString()),
                    ),
                  );
                  break;
                case TableDataType.path:
                  baseCell = TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed(cellValue);
                    },
                    child: const Text('open'),
                  );
                  break;
                case TableDataType.link:
                  baseCell = TextButton(
                    onPressed: () async {
                      await launchUrl(Uri.parse(cellValue));
                    },
                    child: const Text('open'),
                  );
                  break;
                default:
                  baseCell = Text(cellValue.toString());
              }
            }
            if (index == 0) {
              double childLeftSpace = 0;
              childLeftSpace = (data.level.toDouble()) * 16;
              double iconContentSize = 40;
              childLeftSpace += iconContentSize;
              baseCell = Row(
                children: [
                  SizedBox(
                    width: childLeftSpace,
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
                      child: baseCell,
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
                    minHeight:
                        widget.dataRowHeight ??
                        theme.dataTableTheme.dataRowMinHeight ??
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
                      child: baseCell,
                    ),
                  ),
                ),
              ),
            );
          });
          final Border border = Border(top: borderSide);
          List<Widget> content = [];
          bool rowDarker = rowIndex.isEven;
          if (data.level.isEven) rowDarker = !rowDarker;
          double rowOpacity = 0;
          rowOpacity = rowDarker ? 0.02 : 0;
          Color dataRowColor =
              widget.dataRowColor ??
              theme.dataTableTheme.dataRowColor?.resolve(states) ??
              Colors.transparent;
          dataRowColor = dataRowColor.withValues(alpha: rowOpacity);
          Color rowColor = !isFooter
              ? dataRowColor
              : widget.dataFooterColor ?? Colors.transparent;
          Widget rowWidget = Material(
            textStyle:
                widget.dataTextStyle ?? theme.dataTableTheme.dataTextStyle,
            color: rowColor,
            child: Container(
              constraints: BoxConstraints(
                minHeight:
                    widget.dataRowHeight ??
                    theme.dataTableTheme.dataRowMinHeight ??
                    30,
              ),
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: tableColumns.asMap(),
                children: [TableRow(children: cellsBase)],
              ),
            ),
          );
          content.add(rowWidget);
          if (row.child != null && row.active) {
            // TableData childData = row.child!;
            row.child!.active = false;
            row.child!.level = (data.level) + 1;
            row.child!.header = data.header;
            content.add(ExpansionTable(data: row.child!));
            content.add(const SizedBox(height: 32));
          }
          return Container(
            decoration: BoxDecoration(border: border),
            child: Flex(direction: Axis.vertical, children: content),
          );
        }

        List<Widget> rowsList = List.generate(
          data.rows.length,
          (index) => getRows(row: data.rows[index], rowIndex: index),
        );
        if (data.footer != null && data.footer!.isNotEmpty) {
          TableRowData footer = TableRowData(cells: data.footer!);
          rowsList.add(getRows(row: footer, isFooter: true));
        }
        Widget rows = Flex(direction: Axis.vertical, children: rowsList);
        double headingRowHeight =
            widget.headingRowHeight ??
            theme.dataTableTheme.headingRowHeight ??
            56;
        Widget columns = Material(
          elevation: 1,
          textStyle:
              widget.headingTextStyle ?? theme.dataTableTheme.headingTextStyle,
          color:
              widget.headingRowColor ??
              theme.dataTableTheme.headingRowColor?.resolve(states),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: effectiveHorizontalMargin,
            ),
            alignment: Alignment.center,
            height: headingRowHeight,
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: tableColumns.asMap(),
              children: [TableRow(children: columnsList)],
            ),
          ),
        );
        if (data.level > 0) {
          return rows;
        }
        return Scrollbar(
          thumbVisibility: true,
          interactive: true,
          trackVisibility: true,
          controller: controllerHorizontal,
          child: SingleChildScrollView(
            controller: controllerHorizontal,
            scrollDirection: Axis.horizontal,
            primary: false,
            child: Flex(
              direction: Axis.vertical,
              children: [columns, ...rowsList],
            ),
          ),
        );
      },
    );
  }
}
