// File generated by FlutterFire CLI.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCJRNdR0eodnswyi8MHCtF1YOjY235mhM8',
    appId: '1:908593247251:web:d5051593fb23a72022bbe6',
    messagingSenderId: '908593247251',
    projectId: 'fabricelements',
    authDomain: 'fabricelements.firebaseapp.com',
    databaseURL: 'https://fabricelements.firebaseio.com',
    storageBucket: 'fabricelements.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBcKHIu0iuBOTCnv0f9VNP8ntb878eo8Uw',
    appId: '1:908593247251:android:e65c63eaa55aea9d22bbe6',
    messagingSenderId: '908593247251',
    projectId: 'fabricelements',
    databaseURL: 'https://fabricelements.firebaseio.com',
    storageBucket: 'fabricelements.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBrZi43ycLoMg_TCY6Eh54EeAJigdojzE0',
    appId: '1:908593247251:ios:4d0172740bde29da22bbe6',
    messagingSenderId: '908593247251',
    projectId: 'fabricelements',
    databaseURL: 'https://fabricelements.firebaseio.com',
    storageBucket: 'fabricelements.appspot.com',
    iosClientId: '908593247251-7b7npovlmcks6l6qp3dcm07vl049rtmh.apps.googleusercontent.com',
    iosBundleId: 'com.fabricelements.demo',
  );
}