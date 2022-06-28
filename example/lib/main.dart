import 'package:fabric_flutter/component/init_app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'configure_nonweb.dart' if (dart.library.html) 'configure_web.dart';
import 'firebase_options.dart';
import 'my_app.dart';
import 'state/state_global_internal.dart';
import 'state/state_user_internal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load(fileName: 'assets/env');
  configureApp();
  SystemChrome.restoreSystemUIOverlays();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

  /// Init App
  return runApp(InitApp(
    notifications: true,
    links: true,
    child: const MyApp(),
    providers: [
      ChangeNotifierProvider(create: (context) => StateGlobalInternal()),
      ChangeNotifierProvider(create: (context) => StateUserInternal()),
    ],
  ));
}
