import 'dart:async';

import 'package:fabric_flutter/component.dart';
import 'package:fabric_flutter/component/firebase_init.dart';
import 'package:fabric_flutter/component/top_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'configure_nonweb.dart' if (dart.library.html) 'configure_web.dart';
import 'my-app.dart';
import 'state/state-global.dart';
import 'state/state-user-internal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/env");
  configureApp();
  runApp(
    FirebaseInit(
      child: GlobalProviders(
        child: TopApp(
          child: MyApp(),
          notifications: true,
          links: true,
        ),
        providers: [
          ChangeNotifierProvider(create: (context) => StateGlobal()),
          ChangeNotifierProvider(create: (context) => StateUserInternal()),
        ],
      ),
    ),
  );
}
