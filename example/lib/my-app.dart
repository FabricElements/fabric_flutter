import 'package:devicelocale/devicelocale.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/helper/route_helper.dart';
import 'package:fabric_flutter/state/state_user.dart';
import 'package:fabric_flutter/view/view_admin_users.dart';
import 'package:fabric_flutter/view/view_auth_page.dart';
import 'package:fabric_flutter/view/view_hero.dart';
import 'package:fabric_flutter/view/view_profile_edit.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'pages/home-page.dart';
import 'splash/loading.dart';
import 'state/state-global.dart';
import 'state/state-user-internal.dart';
import 'theme.dart';

class MyApp extends StatefulWidget {
  static FirebaseAnalytics analytics = FirebaseAnalytics();
  static FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String language = "en";
  bool loadedRoutes = false;

  void getLanguage() async {
    List languages = (await Devicelocale.preferredLanguages)!;
    String baseLanguage = languages[0];
    String cleanLanguage = baseLanguage.substring(0, 2);
    if (cleanLanguage == "es") {
      language = cleanLanguage;
    }
  }

  @override
  void initState() {
    super.initState();
    getLanguage();
  }

  @override
  Widget build(BuildContext context) {
    StateGlobal stateGlobal = Provider.of<StateGlobal>(context);
    StateUserInternal stateUserInternal =
        Provider.of<StateUserInternal>(context);
    StateUser stateUser = Provider.of<StateUser>(context);
    if (stateUser.signedIn) {
      language = stateUser.serialized.language;
    }

    /// Enable/Disable routes depending on credentials
    RouteHelper routeHelper = RouteHelper(
      initialRoute: "/",
      adminRoutes: [
        '/users',
      ],
      authenticatedRoutes: [
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
    Map<String, WidgetBuilder> _routes = {};
    routeHelper.routesPublic.forEach((key, value) {
      _routes.putIfAbsent(
        key,
        () => (context) {
          if (stateUser.signedIn) return routeHelper.routesSignedIn[key]!;
          return value;
        },
      );
    });

    /// Theme
    ThemeData theme = Theme.of(context).copyWith();
    MyTheme myTheme = MyTheme(theme, Colors.indigo, "light");
    SystemChrome.restoreSystemUIOverlays();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
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

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(language, ""),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      title: 'DEMO',
      theme: myTheme.get,
      initialRoute: "/",
      routes: _routes,
    );
  }
}
