import 'package:charts_flutter/flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// This is a chart graphics widget, used to represent a data series.
///
/// [animate] If set to true, the will animate when opened.
/// [series] This is the series of data used for rendering the
/// [type] What type of chart should be rendered, for example a simple bar chart or pie chart.
/// Charts(
///   type: 'pie-chart',
///   series: createSampleData(dataTotals, 'pie-chart'),
///   animate: true,
/// )
class Charts extends StatefulWidget {
  const Charts({
    Key? key,
    this.animate,
    required this.series,
    required this.type,
  }) : super(key: key);
  final bool? animate;
  final List<Series<dynamic, String>> series;
  final String type;

  @override
  State<Charts> createState() => _ChartsState();
}

class _ChartsState extends State<Charts> {
  final NumberFormat numberFormatDefault = NumberFormat.compact();

  @override
  Widget build(BuildContext context) {
    if (!mounted) {
      return const Text('...');
    }
    Widget chart = const SizedBox();
    switch (widget.type) {
      case 'bar-simple':
        chart = BarChart(
          widget.series, animate: widget.animate!,
          animationDuration: const Duration(milliseconds: 1000),

          /// Assign a custom style for the domain axis.
          domainAxis: OrdinalAxisSpec(
            renderSpec: SmallTickRendererSpec(
              labelStyle: TextStyleSpec(color: MaterialPalette.white.lighter),
              lineStyle: LineStyleSpec(color: MaterialPalette.white.darker),
            ),
          ),

          /// Assign a custom style for the measure axis.
          primaryMeasureAxis: NumericAxisSpec(
            renderSpec: GridlineRendererSpec(
              labelStyle: TextStyleSpec(color: MaterialPalette.white.lighter),
              lineStyle: LineStyleSpec(color: MaterialPalette.white.darker),
            ),
          ),
        );
        break;
      case 'group-bar-simple':
        chart = BarChart(
          widget.series, animate: widget.animate!,
          animationDuration: const Duration(milliseconds: 1000),
          barGroupingType: BarGroupingType.stacked,
          behaviors: [
            SeriesLegend(
              position: BehaviorPosition.top,
              horizontalFirst: true,
              cellPadding: const EdgeInsets.only(right: 4.0, bottom: 16.0),
              showMeasures: true,
              // measureFormatter: (num value) => value is num ? numberFormatDefault.format(value) : '' as String,
              // measureFormatter: (num value) {
              //   String? response;
              //   try {
              //     response = numberFormatDefault.format(value);
              //   } catch (error) {}
              //   return response;
              //   // return value is String
              //   //     ? numberFormatDefault.format(value).toString()
              //   //     : '';
              //   // ignore: unnecessary_null_comparison
              //   // return value == null
              //   //     ? ''
              //   //     : '${numberFormatDefault.format(value)}';
              // },
            ),
          ],

          /// Assign a custom style for the domain axis.
          domainAxis: OrdinalAxisSpec(
              renderSpec: SmallTickRendererSpec(
                  labelStyle:
                      TextStyleSpec(color: MaterialPalette.white.lighter),
                  lineStyle:
                      LineStyleSpec(color: MaterialPalette.white.darker))),

          /// Assign a custom style for the measure axis.
          primaryMeasureAxis: NumericAxisSpec(
              renderSpec: GridlineRendererSpec(
                  labelStyle:
                      TextStyleSpec(color: MaterialPalette.white.lighter),
                  lineStyle:
                      LineStyleSpec(color: MaterialPalette.white.darker))),
        );
        break;
      case 'horizontal-bar':
        chart = BarChart(
          widget.series, animate: widget.animate!,
          animationDuration: const Duration(milliseconds: 1000),
          vertical: false,
          barRendererDecorator: BarLabelDecorator<String>(
            insideLabelStyleSpec: TextStyleSpec(
              color: MaterialPalette.white.lighter,
              fontSize: 16,
            ),
            outsideLabelStyleSpec: TextStyleSpec(
              color: MaterialPalette.white.lighter,
              fontSize: 16,
            ),
          ),

          /// Assign a custom style for the domain axis.
          domainAxis: const OrdinalAxisSpec(renderSpec: NoneRenderSpec()),

          /// Assign a custom style for the measure axis.
          primaryMeasureAxis:
              const NumericAxisSpec(renderSpec: NoneRenderSpec()),
          behaviors: [
            DatumLegend(
              position: BehaviorPosition.start,
            ),
          ],
        );
        break;
      case 'pie-chart':
        chart = PieChart(
          widget.series,
          animate: widget.animate!,
          animationDuration: const Duration(milliseconds: 1000),
          defaultRenderer: ArcRendererConfig(
            arcWidth: 75,
            arcRendererDecorators: [
              ArcLabelDecorator(
                labelPosition: ArcLabelPosition.auto,
                insideLabelStyleSpec: TextStyleSpec(
                  color: MaterialPalette.white.lighter,
                  fontSize: 16,
                ),
                outsideLabelStyleSpec: TextStyleSpec(
                  color: MaterialPalette.white.lighter,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          behaviors: [
            DatumLegend(
              position: BehaviorPosition.top,
            ),
          ],
        );
        break;
    }
    return Padding(
      child: SizedBox(
        height: 380,
        width: double.infinity,
        child: chart,
      ),
      padding: const EdgeInsets.all(16),
    );
  }
}
