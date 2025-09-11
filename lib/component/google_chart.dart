import 'dart:convert';

import 'package:fabric_flutter/component/iframe_minimal.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:flutter/material.dart';

import '../serialized/chart_wrapper.dart';

/// Google Chart
/// This widget uses Google Charts to render charts within an iframe.
/// It constructs an HTML document that loads the Google Charts library,
/// initializes a chart with the provided configuration, and embeds it in an iframe.
/// https://developers.google.com/chart
/// https://developers.google.com/chart/interactive/docs/gallery
/// https://developers.google.com/chart/interactive/docs/reference
class GoogleChart extends StatelessWidget {
  /// Chart configuration data
  final ChartWrapper data;

  const GoogleChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    bool isValid = data.isValid();
    final locales = AppLocalizations.of(context);
    final infoWidget = ListTile(
      leading: const Icon(Icons.info_outline),
      title: Text(locales.get('label--chart-no-data')),
      subtitle: Text(locales.get('label--chart-no-data-description')),
    );
    if (!isValid) {
      return infoWidget;
    }
    try {
      final baseJson = data.toJson();
      final jsonString = jsonEncode(baseJson);
      final chartUrl = Uri.dataFromString(
        '''
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width">
        <title>Chart</title>
        <style>
          html, body, #chart {
            padding: 0;
            margin: 0;
            border: none;
            position: fixed;
            height: 100%;
            width: 100%;
            overflow: hidden;
            pointer-events: auto;
          }
        </style>
        <script src="https://www.gstatic.com/charts/loader.js"></script>
        <script>
          // google.charts.load('current');
          google.charts.load('current', {'packages': ['corechart']});
          google.charts.setOnLoadCallback(drawVisualization);
          function drawVisualization() {
            var wrap = new google.visualization.ChartWrapper($jsonString);
            wrap.draw();
          }
        </script>
      </head>
      <body onresize="drawVisualization()">
      <div id="chart"></div>
      </body>
      </html>
      ''',
        mimeType: 'text/html',
        encoding: Encoding.getByName('utf-8'),
      ).toString();
      return IframeMinimal(src: chartUrl);
    } catch (e) {
      return infoWidget;
    }
  }
}
