
import 'package:fabric_flutter/component/route_page.dart';
import 'package:fabric_flutter/component/user_admin.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/helper/route_helper.dart';
import 'package:fabric_flutter/state/state_user.dart';
import 'package:fabric_flutter/view/view_auth_page.dart';
import 'package:fabric_flutter/view/view_hero.dart';
import 'package:fabric_flutter/view/view_profile_edit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'splash/loading.dart';
import 'theme.dart';

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    StateUser stateUser = Provider.of<StateUser>(context, listen: false);

    // stateUser.streamSerialized.asBroadcastStream()

    /// Theme
    ThemeData theme = Theme.of(context).copyWith();
    MyTheme myTheme = MyTheme(theme, Colors.indigo, "light");
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
    return new MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(stateUser.language, ""),
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

        /// Enable/Disable routes depending on credentials
        final routeHelper = RouteHelper(
          initialRoute: "/",
          adminRoutes: [
            '/users',
          ],
          authenticatedRoutes: [
            '/profile',
          ],
          authRoute: "/sign-in",
          publicRoutes: [
            "/hero",
          ],
          routeMap: {
            "/sign-in": ViewAuthPage(),
            '/': HomePage(),
            '/profile': ViewProfileEdit(loader: LoadingScreen()),
            '/users': UserAdmin(loader: LoadingScreen(), primary: true),
            '/hero': ViewHero(),
          },
          unknownRoute: "/",
        );
        return PageRouteBuilder(
          maintainState: false,
          settings: settings,
          pageBuilder: (_, __, ___) =>
              RoutePage(uri: uri, routeHelper: routeHelper),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
        );
      },
    );
  }
}
