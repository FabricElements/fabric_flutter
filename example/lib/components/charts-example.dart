import 'package:flutter/material.dart';
import 'package:fabric_flutter/components.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:intl/intl.dart';

/// This view id for format data for Dashboard
///
/// Format [createSampleData] for chats
List<charts.Series<FormatData, String>>? createSampleData(data, type) {
  final NumberFormat numberFormatDefault = NumberFormat.compact();
  final NumberFormat numberFormatDecimal = NumberFormat.decimalPattern();

  switch (type) {
    case "bar-simple":
      return [
        charts.Series<FormatData, String>(
          id: 'messageInOut',
          colorFn: (FormatData messages, _) => messages.title.contains("in")
              ? charts.MaterialPalette.yellow.shadeDefault.darker
              : charts.MaterialPalette.indigo.shadeDefault,
          domainFn: (FormatData messages, _) => messages.title,
          measureFn: (FormatData messages, _) => messages.value,
          data: data,
        )
      ];
      break;
    case "group-bar-simple":
      return [
        charts.Series<FormatData, String>(
          id: 'In',
          domainFn: (FormatData messages, _) => messages.title,
          measureFn: (FormatData messages, _) => messages.value,
          data: data[0],
        ),
        charts.Series<FormatData, String>(
          id: 'Out',
          domainFn: (FormatData messages, _) => messages.title,
          measureFn: (FormatData messages, _) => messages.value,
          data: data[1],
        ),
      ];
      break;
    case "horizontal-bar":
      return [
        charts.Series<FormatData, String>(
            id: 'sentiment',
            colorFn: (FormatData messages, _) =>
                messages.title.contains("positive")
                    ? charts.MaterialPalette.indigo.shadeDefault
                    : messages.title.contains("negative")
                        ? charts.MaterialPalette.deepOrange.shadeDefault
                        : messages.title.contains("neutral")
                            ? charts.MaterialPalette.green.shadeDefault.darker
                            : charts.MaterialPalette.purple.shadeDefault,
            domainFn: (FormatData messages, _) => messages.title,
            measureFn: (FormatData messages, _) => messages.value,
            data: data,
            labelAccessorFn: (FormatData messages, _) =>
                '${numberFormatDecimal.format(messages.value)}'),
      ];
      break;
    case "pie-chart":
      return [
        charts.Series<FormatData, String>(
          id: 'messages',
          domainFn: (FormatData message, _) => message.title,
          measureFn: (FormatData message, _) => message.value,
          data: data,
          labelAccessorFn: (FormatData message, _) =>
              '${numberFormatDefault.format(message.value)}',
        ),
      ];
      break;
    default:
      return null;
      break;
  }
}

class FormatData {
  final String title;
  final int value;

  FormatData(this.title, this.value);
}

class ChartsExample extends StatelessWidget {
  ChartsExample({Key? key, required this.scaffoldKey}) : super(key: key);
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    List<FormatData> dataIn = [
      FormatData("One", 10),
      FormatData("Two", 20),
      FormatData("Three", 40),
      FormatData("Four", 30),
    ];
    List<FormatData> dataOut = [
      FormatData("Three", 40),
      FormatData("Four", 30),
      FormatData("One", 10),
      FormatData("Two", 20),
    ];
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: ListView(
          children: <Widget>[
            Charts(
              type: "pie-chart",
              animate: true,
              series: createSampleData(dataIn, "pie-chart")!,
            ),
            Charts(
              type: "horizontal-bar",
              animate: true,
              series: createSampleData(dataIn, "horizontal-bar")!,
            ),
            Charts(
              type: "bar-simple",
              animate: true,
              series: createSampleData(dataIn, "bar-simple")!,
            ),
            Charts(
              type: "group-bar-simple",
              animate: true,
              series: createSampleData([dataIn, dataOut], "group-bar-simple")!,
            )
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
