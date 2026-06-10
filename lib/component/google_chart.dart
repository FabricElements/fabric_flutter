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
/// or invalid. This keeps the surrounding Flutter tree stable even when chart
/// setup fails during rebuilds or when the chart cannot be drawn on the current
/// platform.
///
/// https://developers.google.com/chart
/// https://developers.google.com/chart/interactive/docs/gallery
/// https://developers.google.com/chart/interactive/docs/reference
class GoogleChart extends StatelessWidget {
  /// Stores the Google Charts configuration that will be serialized to JSON.
  ///
  /// Keeping the raw [ChartWrapper] on the widget allows each rebuild to derive
  /// fresh markup and to decide whether a localized fallback should be shown
  /// instead of attempting to render invalid chart data.
  final ChartWrapper data;

  /// Creates a [GoogleChart] from the provided chart configuration.
  ///
  /// Requiring [data] ensures the widget can always validate the chart setup at
  /// build time and provide a predictable fallback instead of relying on `null`
  /// checks deeper in the rendering flow.
  const GoogleChart({super.key, required this.data});

  /// Builds either the embedded chart or a fallback tile when rendering is impossible.
  ///
  /// The [BuildContext] supplies localized fallback copy for invalid data and
  /// serialization failures. Returning the same informational widget for both
  /// cases keeps parent widgets simple because they do not need separate error
  /// handling for malformed chart configuration versus runtime encoding issues.
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
