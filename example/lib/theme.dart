import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MyTheme with Diagnosticable {
  ThemeData themeData;
  MaterialColor? primarySwatch = Colors.indigo;
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
      backgroundColor: Colors.white,
      // scaffoldBackgroundColor: Colors.grey.shade50,
      canvasColor: Colors.white,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // colorScheme: ColorScheme.fromSwatch(
      //   primarySwatch: Colors.indigo,
      //   brightness:Brightness.light,
      // ),
      colorScheme: ColorScheme.light(),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(),
        fillColor: Colors.white,
        filled: true,
      ),
      buttonTheme: ButtonThemeData(
        alignedDropdown: true,
        padding: EdgeInsets.symmetric(horizontal: 16.0),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.grey.shade100,
      ),
      // appBarTheme: AppBarTheme(
      //
      //   centerTitle: false,
      //   // color: Colors.white,
      //   // backgroundColor: Colors.white,
      //   // titleTextStyle: TextStyle(color: Colors.black),
      //   // iconTheme: IconThemeData(
      //   //   color: Colors.teal,
      //   // ),
      //   // actionsIconTheme: IconThemeData(
      //   //   color: Colors.blueGrey.shade700,
      //   // ),
      //   elevation: 1,
      // //   textTheme: TextTheme(
      // //   headline6: TextStyle(
      // //     color: Colors.grey.shade800,
      // //     // fontWeight: FontWeight.bold,
      // //     fontSize: 16,
      // //   ),
      // // ),
      // ),
      // tabBarTheme: TabBarTheme(
      //   labelColor: Colors.black,
      // ),
    );
  }
}
