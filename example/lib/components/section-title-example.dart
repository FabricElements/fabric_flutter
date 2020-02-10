import 'package:flutter/material.dart';
import 'package:fabric_flutter/fabric_flutter.dart';

class SectionTitleExample extends StatelessWidget {
  SectionTitleExample({Key key, @required this.scaffoldKey}) : super(key: key);
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SectionTitle(
        headline: "This is the Section Title demo",
        description: "Click the menu icon to view the other demonstrations",
      ),
    );
  }
}
