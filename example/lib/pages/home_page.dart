import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fabric_flutter/fabric_flutter.dart';
import 'package:fabric_flutter/state/state_api.dart';
import 'package:fabric_flutter/state/state_user.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../splash/loading.dart';
import '../state/state_user_internal.dart';

class HomePage extends StatefulWidget {
  HomePage({
    Key? key,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
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
  }

  @override
  Widget build(BuildContext context) {
    RedirectApp redirectApp =
        RedirectApp(context: context, protected: ["/protected"]);
    StateUserInternal stateUserInternal =
        Provider.of<StateUserInternal>(context);
    StateUser stateUser = Provider.of<StateUser>(context);
    AppLocalizations locales = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    Color backgroundColor = Colors.grey.shade50;
    Widget spacer = Container(height: 16);
    final StateAPI stateAPI = Provider.of<StateAPI>(context);
    stateAPI.endpoint =
        "https://raw.githubusercontent.com/ernysans/laraworld/master/composer.json";
    final StateDocument stateDocument = Provider.of<StateDocument>(context);

    WidgetsBinding.instance?.addPostFrameCallback((_) {
      if (stateAPI.data != null) {
        print("data: ${stateAPI.data}");
        stateDocument.id = "test";
        print("firestore: ${stateDocument.data}");
        if (stateDocument.data.isNotEmpty) {
          stateDocument.callback = () => stateAPI.get();
        }
      } else {
        print("error ${stateAPI.error}");
      }
    });

    /// Dynamic links
    Future<void> _dynamicLinksCallback(
        PendingDynamicLinkData? dynamicLink) async {
      print("Found link: ${dynamicLink?.link}");
      redirectApp.link(link: dynamicLink?.link);
    }

    StateDynamicLinks stateDynamicLinks =
        Provider.of<StateDynamicLinks>(context, listen: false);
    stateDynamicLinks.callback = _dynamicLinksCallback;
    if (stateUser.signedIn) {
      if (stateUser.data.isNotEmpty) {
        loading = false;
      } else {
        Future.delayed(Duration(seconds: 3)).then((value) {
          loading = false;
          if (mounted) setState(() {});
        });
      }
      if (loading) {
        return LoadingScreen();
      }
    }

    /// Validate onboarding
    if (!stateUser.serialized.onboarding.name) {
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

    /// Returns home view widgets
    homeContent() {
      List<Widget> optionsMenu = [
        // spacer,
      ];
      hasOptions = true;

      if (stateUser.admin) {
        hasOptions = true;
        optionsMenu.addAll([
          Container(
            color: Colors.teal.shade50,
            padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(children: [
              ListTile(
                contentPadding: EdgeInsets.all(16),
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
                      margin: EdgeInsets.only(right: 8, left: 16),
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
      Widget _defaultView = CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            automaticallyImplyLeading: false,
            elevation: 0,
            leading: Builder(
              builder: (BuildContext context) {
                return IconButton(
                  color: Colors.black,
                  icon: Icon(Icons.menu_rounded),
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
              stretchModes: <StretchMode>[
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              titlePadding: EdgeInsetsDirectional.only(start: 72, bottom: 16),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(0, 0),
                        end: Alignment(0, 1),
                        colors: <Color>[
                          Colors.teal.shade400,
                          Colors.teal.shade600,
                        ],
                      ),
                    ),
                  ),
                  SmartImage(
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
        _defaultView = ViewFeatured(
          headline: locales.get("home-page--welcome--hello"),
          description: locales.get("home-page--permissions--description"),
          image: "https://images.unsplash.com/photo-1515825838458-f2a94b20105a",
//          actionLabel: locales.get("label--choose-location"),
//          actionUrl: "/campaign/builder-choose-location",
          firstGradientAnimationColor: Color(0xFF161A21),
          secondGradientAnimationColor: Color(0xFF161A21),
          thirdGradientAnimationColor: Color(0xFF161A21),
        );
      }

      String userLastUpdate = stateUser.data["updated"] != null
          ? (stateUser.data["updated"] as Timestamp).seconds.toString()
          : "";
      String _avatarURL =
          stateUser.serialized.avatar + "?size=medium&t=" + userLastUpdate;

      return Scaffold(
        backgroundColor: backgroundColor,
        body: _defaultView,
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              RawMaterialButton(
                fillColor: theme.accentColor,
                onPressed: () {
                  _clearStates();
                  Navigator.pushNamed(context, "/profile");
                },
                child: Container(
                  height: 300,
                  child: DrawerHeader(
                    padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                    child: Center(
                      child: Container(
                        width: 150,
                        height: 160,
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(_avatarURL),
                          backgroundColor: Colors.grey.shade900,
                        ),
                      ),
                    ),
                    decoration: BoxDecoration(
                        color: Color.fromRGBO(0, 0, 0, 0.1),
                        backgroundBlendMode: BlendMode.darken),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.person,
                ),
                title: Text(locales.get("label--profile")),
                onTap: () {
                  Navigator.of(context).pushNamed("/profile");
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(
                  Icons.help,
                ),
                title: Text(locales.get('label--help')),
                onTap: () {
                  Navigator.of(context).pushNamed("/help");
                },
              ),
              Divider(),
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
      String? _onboardingHeadline = "";
      String? _onboardingDescription = "";
      String _onboardingImage = "";
      String? _onboardingActionLabel = "";
      String _onboardingUrl = "";
      if (!stateUser.serialized.onboarding.name) {
        _onboardingHeadline = locales.get("onboarding--profile--title");
        _onboardingDescription =
            locales.get("onboarding--profile--description");
        _onboardingImage =
            "https://images.unsplash.com/photo-1547679904-ac76451d1594";
        _onboardingActionLabel = locales.get("label--continue");
        _onboardingUrl = "/profile";
      }

      defaultWidget = ViewFeatured(
        arguments: {"onboarding": true},
        headline: _onboardingHeadline,
        description: _onboardingDescription,
        image: _onboardingImage,
        actionLabel: _onboardingActionLabel,
        actionUrl: _onboardingUrl,
        firstGradientAnimationColor: Color(0xFF161A21),
        secondGradientAnimationColor: Color(0xFF161A21),
        thirdGradientAnimationColor: Color(0xFF161A21),
      );
    }

    /// Assign this view when the user is loading
    if (stateUser.data.isEmpty) {
      defaultWidget = LoadingScreen();
    }

    /// Show the home if there are no changes to [defaultWidget]
    if (defaultWidget == null) {
      defaultWidget = homeContent();
    }

    return FancyNotification(
      child: defaultWidget,
      labelAction: locales.get("label--open"),
      labelDismiss: locales.get("label--dismiss"),
      callback: (message) {
        if (message["path"] == null || message["path"].toString().isEmpty) {
          return;
        }
        print(message);
        redirectApp.toView(
          path: message["path"],
          params: message,
        );
      },
    );
  }
}
