import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helper/format_data.dart';
import '../serialized/table_data.dart';

/// Builds a hierarchical table from [TableData] with expandable child rows.
///
/// The widget preserves a [DataTable]-style presentation while letting nested
/// datasets appear inline beneath their parent rows. Reusing the parent header
/// definition keeps widths stable across expansion levels so deeply nested data
/// remains readable.
class ExpansionTable extends StatefulWidget {
  /// Creates an [ExpansionTable] for the provided [data].
  ///
  /// The assertion requires a non-empty header whenever [data] is not `null`
  /// so the widget can derive consistent column widths before rendering nested
  /// descendants.
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

  /// Stores the hierarchical table model rendered by this widget.
  ///
  /// Accepting `null` lets callers defer rendering until data is available,
  /// which avoids building placeholder table structure with incomplete columns.
  final TableData? data;

  /// Stores the decoration applied around the rendered table.
  ///
  /// Passing a [Decoration] allows callers to align the table with surrounding
  /// layout chrome without changing the row-building logic.
  ///
  /// {@macro flutter.material.dataTable.decoration}
  final Decoration? decoration;

  /// Stores the color used for footer rows.
  ///
  /// A dedicated footer color helps summary rows remain visually distinct from
  /// regular data rows when totals or aggregate values are displayed.
  ///
  /// {@macro flutter.material.dataTable.dataRowColor}
  /// {@macro flutter.material.DataTable.dataRowColor}
  final Color? dataFooterColor;

  /// Stores the base color used for standard data rows.
  ///
  /// The value is combined with alternating opacity so long tables are easier
  /// to scan without introducing separate row widgets or theme variants.
  ///
  /// {@macro flutter.material.dataTable.dataRowColor}
  /// {@macro flutter.material.DataTable.dataRowColor}
  final Color? dataRowColor;

  /// Stores the minimum height applied to each data row.
  ///
  /// Allowing callers to override row height helps dense and spacious table
  /// layouts share the same rendering logic.
  ///
  /// {@macro flutter.material.dataTable.dataRowHeight}
  final double? dataRowHeight;

  /// Stores the text style used for data cells.
  ///
  /// Overriding the default text style helps nested content match the visual
  /// hierarchy of the host screen without reformatting individual cells.
  ///
  /// {@macro flutter.material.dataTable.dataTextStyle}
  final TextStyle? dataTextStyle;

  /// Stores the color used for the heading row.
  ///
  /// A custom heading color can reinforce table grouping and keep the root
  /// header visually anchored above expandable content.
  ///
  /// {@macro flutter.material.dataTable.headingRowColor}
  /// {@macro flutter.material.DataTable.headingRowColor}
  final Color? headingRowColor;

  /// Stores the height used for the heading row.
  ///
  /// Customizing the heading height helps the widget fit compact tool panels or
  /// larger dashboard layouts while keeping column labels aligned.
  ///
  /// {@macro flutter.material.dataTable.headingRowHeight}
  final double? headingRowHeight;

  /// Stores the text style used for heading labels.
  ///
  /// A separate heading style keeps column titles legible and visually distinct
  /// from cell content across different themes.
  ///
  /// {@macro flutter.material.dataTable.headingTextStyle}
  final TextStyle? headingTextStyle;

  /// Stores the horizontal margin applied around each row.
  ///
  /// Matching [DataTable] margin behavior makes the widget easier to drop into
  /// existing table layouts without unexpected spacing differences.
  ///
  /// {@macro flutter.material.dataTable.horizontalMargin}
  final double? horizontalMargin;

  /// Stores the spacing inserted between adjacent columns.
  ///
  /// When the value is `null`, [DataTableThemeData.columnSpacing] is used and
  /// falls back to `56.0` so the table continues to follow Material spacing
  /// expectations.
  ///
  /// {@macro flutter.material.dataTable.columnSpacing}
  final double? columnSpacing;

  /// Stores the thickness used for row dividers.
  ///
  /// Exposing divider thickness lets callers balance separation and density in
  /// wide tables that may contain many expandable levels.
  ///
  /// {@macro flutter.material.dataTable.dividerThickness}
  final double? dividerThickness;

  /// Stores the border painted around each cell.
  ///
  /// Providing a [TableBorder] makes it possible to emphasize boundaries for
  /// reporting-style tables without altering row composition.
  final TableBorder? border;

  /// Creates the mutable state for [ExpansionTable].
  ///
  /// Using a dedicated [_ExpansionTableState] preserves expansion toggles while
  /// rows rebuild in response to user interaction.
  @override
  State<ExpansionTable> createState() => _ExpansionTableState();
}

/// Stores the fixed width assigned to each column.
///
/// Sharing one top-level width keeps parent and child tables visually aligned
/// after expansion, which avoids jitter when nested rows appear.
double _widthColumn = 350;

/// Manages recursive row rendering for [ExpansionTable].
///
/// Keeping the expansion behavior in state allows the widget to toggle nested
/// tables in place without requiring external controllers.
class _ExpansionTableState extends State<ExpansionTable> {
  /// Builds the current table level for the given [BuildContext].
  ///
  /// Root tables render headers and horizontal scrolling, while nested tables
  /// return only their rows so expanded content can appear directly beneath the
  /// parent row that revealed it.
  @override
  Widget build(BuildContext context) {
    if (widget.data == null) return const SizedBox();
    TableData data = widget.data!;
    final theme = Theme.of(context);
    Set<WidgetState> states = <WidgetState>{};
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
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
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
                    minHeight: widget.dataRowHeight ??
                        theme.dataTableTheme.dataRowMinHeight ??
                        30,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
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
          Color dataRowColor = widget.dataRowColor ??
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
                minHeight: widget.dataRowHeight ??
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
        double headingRowHeight = widget.headingRowHeight ??
            theme.dataTableTheme.headingRowHeight ??
            56;
        Widget columns = Material(
          elevation: 1,
          textStyle:
              widget.headingTextStyle ?? theme.dataTableTheme.headingTextStyle,
          color: widget.headingRowColor ??
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
