import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MyTheme with Diagnosticable {
  ThemeData themeData;
  MaterialColor? primarySwatch = Colors.blue;
  String? theme = "light";

  MyTheme(this.themeData, this.primarySwatch, this.theme);

  ThemeData get light {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: primarySwatch,
    );
  }

  ThemeData get get {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.blueGrey,
      accentColor: Colors.indigo,
      backgroundColor: Colors.white,
      scaffoldBackgroundColor: Colors.white,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        brightness: Brightness.light,
        color: Colors.white,
        // backgroundColor: Colors.white,
        titleTextStyle: TextStyle(color: Colors.black),
        iconTheme: IconThemeData(
          color: Colors.teal,
        ),
        actionsIconTheme: IconThemeData(
          color: Colors.blueGrey.shade700,
        ),
        elevation: 1,
        textTheme: TextTheme(
          headline6: TextStyle(
            color: Colors.grey.shade800,
            // fontWeight: FontWeight.bold,
            fontSize: 28.0,
          ),
        ),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: Colors.black,
      ),
    );
  }
}
