import 'dart:async';

import 'package:devicelocale/devicelocale.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/helper/route_helper.dart';
import 'package:fabric_flutter/state/state_user.dart';
import 'package:fabric_flutter/view/view_admin_users.dart';
import 'package:fabric_flutter/view/view_auth_page.dart';
import 'package:fabric_flutter/view/view_hero.dart';
import 'package:fabric_flutter/view/view_profile_edit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'splash/loading.dart';
import 'state/state_user_internal.dart';
import 'theme.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String language = "en";
  bool init = false;

  void getLanguage() async {
    List languages = (await Devicelocale.preferredLanguages)!;
    String baseLanguage = languages[0];
    String cleanLanguage = baseLanguage.substring(0, 2);
    if (cleanLanguage == "es") {
      language = cleanLanguage;
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    init = false;
    getLanguage();
    if (mounted && !init) {
      Timer(Duration(seconds: 2), () {
        if (!init) {
          init = true;
          if (mounted) setState(() {});
        }
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // StateGlobal stateGlobal = Provider.of<StateGlobal>(context);
    StateUserInternal stateUserInternal =
    Provider.of<StateUserInternal>(context);
    StateUser stateUser = Provider.of<StateUser>(context);
    if (stateUser.signedIn) {
      language = stateUser.serialized.language;
    }

    /// Theme
    ThemeData theme = Theme.of(context).copyWith();
    MyTheme myTheme = MyTheme(theme, Colors.indigo, "light");
    SystemChrome.restoreSystemUIOverlays();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates = [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
    Iterable<Locale> supportedLocales = [
      Locale.fromSubtags(languageCode: "en"),
      Locale.fromSubtags(languageCode: "es"),
    ];

    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(language, ""),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      title: 'DEMO',
      theme: myTheme.get,
      initialRoute: "/",
      onGenerateRoute: (settings) {
        Map<String, dynamic> arguments = settings.arguments != null
            ? settings.arguments as Map<String, dynamic>
            : {}; // Retrieve the value
        Uri uri = Uri.parse(settings.name ?? "/");
        final queryParameters = uri.queryParameters;
        final queryParametersAll = uri.queryParametersAll;

        /// Enable/Disable routes depending on credentials
        RouteHelper routeHelper = RouteHelper(
          context: context,
          initialRoute: "/",
          adminRoutes: [
            '/users',
          ],
          authenticatedRoutes: [
            '/users',
            '/profile',
          ],
          authRoute: "/sign-in",
          isAdmin: stateUser.admin,
          publicRoutes: [
            "/hero",
          ],
          routeMap: {
            "/sign-in": ViewAuthPage(),
            '/': HomePage(),
            '/profile': ViewProfileEdit(loader: LoadingScreen()),
            '/users': ViewAdminUsers(loader: LoadingScreen()),
            '/hero': ViewHero(),
          },
          signedIn: stateUser.signedIn,
          unknownRoute: "/",
        );
        Widget page = LoadingScreen(parent: true);
        Map<String, Widget> _routes = routeHelper.routes(stateUser.signedIn);
        if (_routes.containsKey(uri.path)) {
          page = _routes[uri.path]!;
        }
        // return MaterialPageRoute(settings: settings, builder: (_) => page);
        return PageRouteBuilder(
          maintainState: false,
          settings: settings,
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
        );
      },
    );
    return StreamBuilder(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        Widget _app =
            Center(child: CircularProgressIndicator(color: Colors.indigo));
        if (init) {
          switch (snapshot.connectionState) {
            case ConnectionState.active:
            case ConnectionState.done:
              _app = app;
              break;
            default:
          }
        }
        return _app;
      },
    );
  }
}
