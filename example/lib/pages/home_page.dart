import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fabric_flutter/component/card_button.dart';
import 'package:fabric_flutter/component/logs_list.dart';
import 'package:fabric_flutter/component/smart_image.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:fabric_flutter/helper/redirect_app.dart';
import 'package:fabric_flutter/state/state_alert.dart';
import 'package:fabric_flutter/state/state_dynamic_links.dart';
import 'package:fabric_flutter/state/state_notifications.dart';
import 'package:fabric_flutter/state/state_user.dart';
import 'package:fabric_flutter/view/view_featured.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../splash/loading.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late bool hasOptions;
  late bool pendingOnboarding;
  late bool loading;

  @override
  void initState() {
    super.initState();
    hasOptions = false;
    pendingOnboarding = false;
    loading = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // context.dependOnInheritedWidgetOfExactType();
  }

  @override
  void dispose() {
    super.dispose();
    // context.dependOnInheritedWidgetOfExactType();
  }

  @override
  Widget build(BuildContext context) {
    RedirectApp redirectApp =
        RedirectApp(context: context, protected: ["/protected"]);
    final stateUser = Provider.of<StateUser>(context);
    StateNotifications stateNotifications =
        Provider.of<StateNotifications>(context, listen: false);
    AppLocalizations locales = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    Color backgroundColor = Colors.grey.shade50;
    Widget spacer = Container(height: 16);
    final alert = Provider.of<StateAlert>(context, listen: false);

    /// Assign notification callback
    stateNotifications.callback = (Map<String, dynamic> message) {
      /// TODO: format message as queryParameters for redirection
      return alert.show(AlertData(
        title: message["title"],
        body: message["body"],
        // path: message["path"],
        image: message["image"],
        // arguments: message,
        typeString: message["type"],
      ));
    };

    /// Dynamic links
    Future<void> _dynamicLinksCallback(
        PendingDynamicLinkData? dynamicLink) async {
      print("Found link: ${dynamicLink?.link}");
      redirectApp.link(link: dynamicLink?.link);
    }

    StateDynamicLinks stateDynamicLinks =
        Provider.of<StateDynamicLinks>(context, listen: false);
    stateDynamicLinks.callback = _dynamicLinksCallback;
    if (stateUser.data.isNotEmpty) {
      loading = false;
    }
    if (loading) {
      return LoadingScreen();
    }

    /// Validate onboarding
    if (stateUser.serialized.onboarding != null &&
        !stateUser.serialized.onboarding!.name) {
      pendingOnboarding = true;
    } else {
      pendingOnboarding = false;
    }

    /// Clear global state
    void _clearStates() {
      if (mounted) {
        try {
          // stateToReset.clear();
        } catch (error) {}
      }
    }

    void actionCall(dynamic id) {
      print("id: $id");
    }

    /// Returns home view widgets
    homeContent() {
      List<Widget> optionsMenu = [
        LogsList(
          minimal: true,
          actions: [
            ButtonOptions(label: "Load version", value: 1, onTap: actionCall),
            ButtonOptions(
                label: "Rollback changes", value: 1, onTap: actionCall)
          ],
          data: const [
            {
              'text':
                  '{Donec} nec {justo} eget felis facilisis fermentum. Aliquam porttitor mauris sit amet orci. Aenean dignissim pellentesque felis.',
              'id': 'hello',
              'timestamp': "2021-11-09T09:25:27",
            },
            {
              'text':
                  'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.',
              'id': 'test',
              'timestamp': "2021-11-09T21:16:27"
            },
            {
              'text':
                  '{@Vcr3IZKdvqepEj51vjM8xqLxzfq1} Vestibulum commodo {@VnCYNfYzlVQc3fCAJH2LyNv9vGj2} felis quis tortor. Aliquam {porttitor} mauris sit amet orci. {Aenean dignissim} pellentesque felis.',
              'id': 'demo',
              'timestamp': "2021-11-09T20:23:27"
            },
          ],
        ),
        // spacer,
      ];
      hasOptions = true;

      if (stateUser.admin) {
        hasOptions = true;
        optionsMenu.addAll([
          Container(
            color: Colors.teal.shade50,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(children: [
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  locales.get("users"),
                  style: textTheme.headline4!.copyWith(color: Colors.teal),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: CardButton(
                      height: 165,
                      margin: const EdgeInsets.only(right: 8, left: 16),
                      headline: locales.get("label--admin"),
                      image:
                          "https://images.unsplash.com/photo-1513171920216-2640b288471b",
                      onPressed: () {
                        _clearStates();
                        Navigator.pushNamed(
                          context,
                          "/users",
                          arguments: {"type": "admin"},
                        );
                      },
                    ),
                  ),
                ],
              ),
            ]),
          ),
          spacer,
        ]);
      }

      /// Add space at the end of the widgets
      optionsMenu.add(spacer);
      Widget defaultView = CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            automaticallyImplyLeading: false,
            elevation: 0,
            leading: Builder(
              builder: (BuildContext context) {
                return IconButton(
                  color: Colors.black,
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                  tooltip:
                      MaterialLocalizations.of(context).openAppDrawerTooltip,
                );
              },
            ),
            stretch: false,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const <StretchMode>[
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              titlePadding:
                  const EdgeInsetsDirectional.only(start: 72, bottom: 16),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(0, 0),
                        end: const Alignment(0, 1),
                        colors: <Color>[
                          Colors.teal.shade400,
                          Colors.teal.shade600,
                        ],
                      ),
                    ),
                  ),
                  const SmartImage(
                      url:
                          "https://images.unsplash.com/photo-1557696859-ebd88b12be5e"),
                  // DecoratedBox(
                  //   decoration: BoxDecoration(
                  //     gradient: LinearGradient(
                  //       begin: Alignment(0.0, 0.0),
                  //       end: Alignment(0.0, 1),
                  //       colors: <Color>[
                  //         backgroundColor.withOpacity(0),
                  //         backgroundColor.withOpacity(.1),
                  //         backgroundColor,
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  // Positioned(
                  //   left: 0,
                  //   right: 0,
                  //   bottom: 32,
                  //   child: SafeArea(
                  //     bottom: false,
                  //     child: Padding(
                  //       padding: EdgeInsets.only(
                  //           top: 64, bottom: 16, left: 16, right: 16),
                  //       child: Wrap(
                  //         direction: Axis.vertical,
                  //         children: <Widget>[
                  //           Padding(
                  //             padding: EdgeInsets.only(bottom: 8),
                  //             child: Text(
                  //               locales.get("home-page--welcome"),
                  //               style: textTheme.headline4!
                  //                   .copyWith(color: Colors.white),
                  //             ),
                  //           ),
                  //           Padding(
                  //             padding: EdgeInsets.only(bottom: 8),
                  //             child: Text(
                  //               locales.get("home-page--welcome--hello"),
                  //               style: textTheme.subtitle1!
                  //                   .copyWith(color: Colors.white),
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //     ),
                  //   ),
                  // )
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate(optionsMenu),
          ),
        ],
      );

      if (!hasOptions) {
        defaultView = ViewFeatured(
          headline: locales.get("home-page--welcome--hello"),
          description: locales.get("home-page--permissions--description"),
          image: "https://images.unsplash.com/photo-1515825838458-f2a94b20105a",
//          actionLabel: locales.get("label--choose-location"),
//          actionUrl: "/campaign/builder-choose-location",
          firstGradientAnimationColor: const Color(0xFF161A21),
          secondGradientAnimationColor: const Color(0xFF161A21),
          thirdGradientAnimationColor: const Color(0xFF161A21),
        );
      }

      String userLastUpdate = stateUser.data["updated"] != null
          ? (stateUser.data["updated"] as Timestamp).seconds.toString()
          : "";
      String avatarURL =
          "${stateUser.serialized.avatar}?size=medium&t=$userLastUpdate";

      return Scaffold(
        backgroundColor: backgroundColor,
        body: defaultView,
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              RawMaterialButton(
                fillColor: theme.colorScheme.secondary,
                onPressed: () {
                  _clearStates();
                  Navigator.pushNamed(context, "/profile");
                },
                child: SizedBox(
                  height: 300,
                  child: DrawerHeader(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                    decoration: const BoxDecoration(
                        color: Color.fromRGBO(0, 0, 0, 0.1),
                        backgroundBlendMode: BlendMode.darken),
                    child: Center(
                      child: SizedBox(
                        width: 150,
                        height: 160,
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(avatarURL),
                          backgroundColor: Colors.grey.shade900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.person,
                ),
                title: Text(locales.get("label--profile")),
                onTap: () {
                  Navigator.of(context).pushNamed("/profile");
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.help,
                ),
                title: Text(locales.get('label--help')),
                onTap: () {
                  Navigator.of(context).pushNamed("/help");
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.exit_to_app,
                  color: Colors.redAccent.shade200,
                ),
                title: Text(locales.get("label--sign-out"),
                    style: TextStyle(color: Colors.redAccent.shade200)),
                onTap: () {
                  stateUser.signOut();
                  // Navigator.popAndPushNamed(context, "/sing-in");
                },
              ),
            ],
          ),
        ),
      );
    }

    Widget? defaultWidget;

    if (stateUser.signedIn &&
        stateUser.id != null &&
        stateUser.data.isNotEmpty &&
        pendingOnboarding) {
      String? onboardingHeadline = "";
      String? onboardingDescription = "";
      String onboardingImage = "";
      String? onboardingActionLabel = "";
      String onboardingUrl = "";
      if (stateUser.serialized.onboarding != null && !stateUser.serialized.onboarding!.name) {
        onboardingHeadline = locales.get("onboarding--profile--title");
        onboardingDescription = locales.get("onboarding--profile--description");
        onboardingImage =
            "https://images.unsplash.com/photo-1547679904-ac76451d1594";
        onboardingActionLabel = locales.get("label--continue");
        onboardingUrl = "/profile";
      }

      defaultWidget = ViewFeatured(
        arguments: const {"onboarding": true},
        headline: onboardingHeadline,
        description: onboardingDescription,
        image: onboardingImage,
        actionLabel: onboardingActionLabel,
        actionUrl: onboardingUrl,
        firstGradientAnimationColor: const Color(0xFF161A21),
        secondGradientAnimationColor: const Color(0xFF161A21),
        thirdGradientAnimationColor: const Color(0xFF161A21),
      );
    }

    /// Show the home if there are no changes to [defaultWidget]
    defaultWidget ??= homeContent();

    return defaultWidget;
  }
}
