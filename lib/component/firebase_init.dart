import 'package:cloud_functions/cloud_functions.dart';
import 'package:fabric_flutter/placeholder/loading_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

class FirebaseInit extends StatelessWidget {
  FirebaseInit({
    Key? key,
    required this.child,
    this.loader,
  }) : super(key: key);
  final Widget child;
  final Widget? loader;

  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    if (!kReleaseMode) {
      FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
    }
    Widget loadingApp = MaterialApp(
      debugShowCheckedModeBanner: false,
      home: this.loader ?? LoadingScreen(),
    );
    return FutureBuilder(
      // Initialize FlutterFire:
      future: _initialization,
      builder: (context, snapshot) {
        // Check for errors
        if (snapshot.hasError) {
          print(snapshot.error.toString());
          return loadingApp;
        }

        // Once complete, show your application
        if (snapshot.connectionState == ConnectionState.done) {
          return child;
        }

        // Otherwise, show something whilst waiting for initialization to complete
        return loadingApp;
      },
    );
  }
}
