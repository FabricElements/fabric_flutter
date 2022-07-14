import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/state/state_document.dart';
import 'package:fabric_flutter/state/state_user.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'navigation.dart';

class ExampleApp extends StatelessWidget {
  const ExampleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => StateDocument()),
        ChangeNotifierProvider(create: (context) => StateUser()),
      ],
      child: MaterialApp(
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
        initialRoute: "/admin-users",
        onGenerateRoute: routes,
      ),
      // child: TopApp(
      //
      //   // notifications: true,
      //   // links: true,
      // ),
    );
  }
}
