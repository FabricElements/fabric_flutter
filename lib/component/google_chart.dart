import 'dart:convert';

import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../serialized/chart_wrapper.dart';
import 'iframe_minimal.dart';

/// Renders a Google Chart inside a minimal iframe-backed HTML document.
///
/// The widget serializes [data] into the JavaScript configuration expected by
/// Google's `ChartWrapper`, embeds the generated document in an iframe, and
/// falls back to localized explanatory copy whenever the chart data is missing
/// or invalid. This keeps the Flutter tree stable even when chart setup fails
/// during rebuilds.
///
/// https://developers.google.com/chart
/// https://developers.google.com/chart/interactive/docs/gallery
/// https://developers.google.com/chart/interactive/docs/reference
class GoogleChart extends StatelessWidget {
  /// Stores the Google Charts configuration that will be serialized to JSON.
  final ChartWrapper data;

  /// Creates a [GoogleChart] from the provided chart configuration.
  ///
  /// The constructor keeps [data] required so the widget can decide at build
  /// time whether to render the chart or show a localized fallback state.
  const GoogleChart({super.key, required this.data});

  /// Builds either the embedded chart or a fallback tile when rendering is impossible.
  ///
  /// Invalid data and serialization failures both resolve to the same friendly
  /// message so parents do not need custom error handling for common edge cases.
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
