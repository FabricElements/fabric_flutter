import 'package:flutter/material.dart';

class MyTheme {
  ThemeData get light => ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blueGrey,
        accentColor: Colors.teal,
        backgroundColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          brightness: Brightness.light,
          color: Colors.white,
          iconTheme: IconThemeData(
            color: Colors.teal,
          ),
          actionsIconTheme: IconThemeData(
            color: Colors.blueGrey.shade700,
          ),
          elevation: 1,
        ),
        tabBarTheme: TabBarTheme(
          labelColor: Colors.black,
        ),
      );
}
