import 'package:flutter/material.dart';

/// This is an alert class, depending on the type of alert wanted a snackbar will be displayed.
/// Alert(
///   context: context,
///   mounted: mounted,
/// ).show(
///   text: "Something went wrong...",
///   type: "error",
/// );
class Alert {
  const Alert({
    @required this.context,
    @required this.mounted,
  });

  final BuildContext context;
  final bool mounted;

  void show({
    @required String text,
    int duration = 3,
    String type, // null, "error", "success"
    String widget,
  }) {
    try {
      Color color;
      switch (type) {
        case "error":
          color = Colors.red.shade500;
          duration = duration != 3 ? duration : 6;
          print("Error alert: $text");
          break;
        case "success":
          color = Colors.green.shade500;
          break;
        default:
          color = Colors.grey.shade800;
      }
      final _duration = Duration(seconds: duration);
      switch (widget) {
        default:
          Scaffold.of(context).showSnackBar(
            SnackBar(
              content: Text(
                text,
                style: TextStyle(color: Colors.white),
              ),
              duration: _duration,
              backgroundColor: color,
            ),
          );
      }
    } catch (error) {
      print(error);
    }
  }
}
