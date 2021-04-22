import 'package:fabric_flutter/helpers.dart';
import 'package:flutter/material.dart';

import 'navigation.dart';

class ExampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fabric Flutter demo',
      locale: Locale("en"),
      localizationsDelegates: [
        AppLocalizationsDelegate(),
//        GlobalMaterialLocalizations.delegate,
//        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en', ''),
        const Locale('es', ''),
      ],
      theme: ThemeData(
        primarySwatch: Colors.purple,
        // backgroundColor: Colors.grey.shade900,
        // scaffoldBackgroundColor: Colors.grey.shade900,
        // textTheme: TextTheme(
        //   headline: TextStyle(
        //     color: Colors.white,
        //   ),
        // ),
        // secondaryHeaderColor: Colors.grey.shade900,
      ),
      initialRoute: "/",
      onGenerateRoute: routes,
    );
  }
}
