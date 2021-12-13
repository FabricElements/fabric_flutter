import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
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

  emulators() async {
    if (kDebugMode) {
      FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      // FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget loadingApp = Container(color: Colors.grey.shade50);
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
          emulators();
          return child;
        }

        // Otherwise, show something whilst waiting for initialization to complete
        return loadingApp;
      },
    );
  }
}
