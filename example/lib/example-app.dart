import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fabric_flutter/helpers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'navigation.dart';

Future<void> initializeDefault() async {
  late FirebaseApp? app = null;
  if (app != null) return;
  app = await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = Settings(persistenceEnabled: false);
  assert(app != null);
}

class ExampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    initializeDefault();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => StateDocument()),
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
        initialRoute: "/state-document",
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
