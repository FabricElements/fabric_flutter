import 'package:fabric_flutter/component/section_title.dart';
import 'package:flutter/material.dart';

class SectionTitleExample extends StatelessWidget {
  SectionTitleExample({Key? key, required this.scaffoldKey}) : super(key: key);
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SectionTitle(
        headline: "This is the Section Title demo",
        description: "Click the menu icon to view the other demonstrations",
      ),
    );
  }
}
