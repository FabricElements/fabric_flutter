import 'dart:async';

import 'package:fabric_flutter/component/init_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'configure_nonweb.dart' if (dart.library.html) 'configure_web.dart';
import 'my_app.dart';
import 'state/state_global_internal.dart';
import 'state/state_user_internal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/env");
  configureApp();
  SystemChrome.restoreSystemUIOverlays();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

  /// Init App
  runApp(InitApp(
    notifications: true,
    links: true,
    child: MyApp(),
    providers: [
      ChangeNotifierProvider(create: (context) => StateGlobalInternal()),
      ChangeNotifierProvider(create: (context) => StateUserInternal()),
    ],
  ));
}
