import 'package:devicelocale/devicelocale.dart';
import 'package:fabric_flutter/component/admin_users.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/state/state_user.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'pages/auth-page.dart';
import 'pages/home-page.dart';
import 'pages/profile-page.dart';
import 'state/state-global.dart';
import 'state/state-user-internal.dart';
import 'theme.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

class MyApp extends StatefulWidget {
  static FirebaseAnalytics analytics = FirebaseAnalytics();
  static FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  late String language;

  void getLanguage() async {
    List languages = (await Devicelocale.preferredLanguages)!;
    String baseLanguage = languages[0];
    String cleanLanguage = baseLanguage.substring(0, 2);
    if (cleanLanguage == 'es') {
      language = cleanLanguage;
      if (mounted) setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    language = "en";
    getLanguage();
  }

  @override
  Widget build(BuildContext context) {
    StateGlobal stateGlobal = Provider.of<StateGlobal>(context);
    StateUserInternal stateUserInternal =
        Provider.of<StateUserInternal>(context);
    StateUser stateUser = Provider.of<StateUser>(context);
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    void _signOut() async {
      stateUser.clear();
      await _auth.signOut();
    }

    SystemChrome.restoreSystemUIOverlays();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    final _home = WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        primary: false,
        body: HomePage(signOut: _signOut),
      ),
    );
    Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates = [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
    Iterable<Locale> supportedLocales = [
      Locale.fromSubtags(languageCode: "en"),
      // Locale.fromSubtags(languageCode: "es"),
    ];
    if (!stateUser.signedIn) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(language, ""),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        title: 'DEMO',
        theme: MyTheme().light,
        home: AuthPage(),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      locale: Locale(language, ""),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      title: 'DEMO',
      theme: MyTheme().light,
      initialRoute: "/",
      routes: {
        '/': (context) => _home,
        '/home': (context) => _home,
        '/profile': (context) => Scaffold(primary: false, body: ProfilePage()),
        '/users': (context) => Scaffold(primary: false, body: AdminUsers()),
      },
    );
  }
}
