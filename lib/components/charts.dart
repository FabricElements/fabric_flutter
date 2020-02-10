import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// This is a chart graphics widget, used to represent a data series.
///
/// [animate] If set to true, the charts will animate when opened.
/// [series] This is the series of data used for rendering the charts.
/// [type] What type of chart should be rendered, for example a simple bar chart or pie chart.
/// Charts(
///   type: "pie-chart",
///   series: createSampleData(dataTotals, "pie-chart"),
///   animate: true,
/// )
class Charts extends StatefulWidget {
  Charts({
    Key key,
    this.animate,
    @required this.series,
    @required this.type,
  }) : super(key: key);
  final bool animate;
  final List<charts.Series> series;
  final String type;

  @override
  _ChartsState createState() => _ChartsState();
}

class _ChartsState extends State<Charts> {
  final NumberFormat numberFormatDefault = NumberFormat.compact();

  @override
  Widget build(BuildContext context) {
    if (!mounted) {
      return Text("...");
    }
    var chart;
    switch (widget.type) {
      case "bar-simple":
        chart = charts.BarChart(
          widget.series, animate: widget.animate,
          animationDuration: Duration(milliseconds: 1000),

          /// Assign a custom style for the domain axis.
          domainAxis: charts.OrdinalAxisSpec(
            renderSpec: charts.SmallTickRendererSpec(
              labelStyle: charts.TextStyleSpec(
                  color: charts.MaterialPalette.white.lighter),
              lineStyle: charts.LineStyleSpec(
                  color: charts.MaterialPalette.white.darker),
            ),
          ),

          /// Assign a custom style for the measure axis.
          primaryMeasureAxis: charts.NumericAxisSpec(
            renderSpec: charts.GridlineRendererSpec(
              labelStyle: charts.TextStyleSpec(
                  color: charts.MaterialPalette.white.lighter),
              lineStyle: charts.LineStyleSpec(
                  color: charts.MaterialPalette.white.darker),
            ),
          ),
        );
        break;
      case "group-bar-simple":
        chart = charts.BarChart(
          widget.series, animate: widget.animate,
          animationDuration: Duration(milliseconds: 1000),
          barGroupingType: charts.BarGroupingType.stacked,
          behaviors: [
            charts.SeriesLegend(
              position: charts.BehaviorPosition.top,
              horizontalFirst: true,
              cellPadding: EdgeInsets.only(right: 4.0, bottom: 16.0),
              showMeasures: true,
              measureFormatter: (num value) {
                return value == null
                    ? ''
                    : '${numberFormatDefault.format(value)}';
              },
            ),
          ],

          /// Assign a custom style for the domain axis.
          domainAxis: charts.OrdinalAxisSpec(
              renderSpec: charts.SmallTickRendererSpec(
                  labelStyle: charts.TextStyleSpec(
                      color: charts.MaterialPalette.white.lighter),
                  lineStyle: charts.LineStyleSpec(
                      color: charts.MaterialPalette.white.darker))),

          /// Assign a custom style for the measure axis.
          primaryMeasureAxis: charts.NumericAxisSpec(
              renderSpec: charts.GridlineRendererSpec(
                  labelStyle: charts.TextStyleSpec(
                      color: charts.MaterialPalette.white.lighter),
                  lineStyle: charts.LineStyleSpec(
                      color: charts.MaterialPalette.white.darker))),
        );
        break;
      case "horizontal-bar":
        chart = charts.BarChart(
          widget.series, animate: widget.animate,
          animationDuration: Duration(milliseconds: 1000),
          vertical: false,
          barRendererDecorator: charts.BarLabelDecorator<String>(
            insideLabelStyleSpec: charts.TextStyleSpec(
              color: charts.MaterialPalette.white.lighter,
              fontSize: 16,
            ),
            outsideLabelStyleSpec: charts.TextStyleSpec(
              color: charts.MaterialPalette.white.lighter,
              fontSize: 16,
            ),
          ),

          /// Assign a custom style for the domain axis.
          domainAxis:
          charts.OrdinalAxisSpec(renderSpec: charts.NoneRenderSpec()),

          /// Assign a custom style for the measure axis.
          primaryMeasureAxis:
          charts.NumericAxisSpec(renderSpec: charts.NoneRenderSpec()),
          behaviors: [
            charts.DatumLegend(
              position: charts.BehaviorPosition.start,
            ),
          ],
        );
        break;
      case "pie-chart":
        chart = charts.PieChart(
          widget.series,
          animate: widget.animate,
          animationDuration: Duration(milliseconds: 1000),
          defaultRenderer: charts.ArcRendererConfig(
            arcWidth: 75,
            arcRendererDecorators: [
              charts.ArcLabelDecorator(
                labelPosition: charts.ArcLabelPosition.auto,
                insideLabelStyleSpec: charts.TextStyleSpec(
                  color: charts.MaterialPalette.white.lighter,
                  fontSize: 16,
                ),
                outsideLabelStyleSpec: charts.TextStyleSpec(
                  color: charts.MaterialPalette.white.lighter,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          behaviors: [
            charts.DatumLegend(
              position: charts.BehaviorPosition.top,
            ),
          ],
        );
        break;
    }
    return Padding(
      child: Container(
        height: 380,
        width: double.infinity,
        child: chart,
      ),
      padding: EdgeInsets.all(16),
    );
  }
}
