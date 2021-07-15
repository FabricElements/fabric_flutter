import 'package:fabric_flutter_example/helpers/state_document.dart';
import 'package:flutter/material.dart';
import 'components/card-button-example.dart';
import 'components/charts-example.dart';
import 'components/chips-example.dart';
import 'components/featured-view-example.dart';
import 'components/invitation-example.dart';
import 'components/language-selector-example.dart';
import 'components/preview-audio-example.dart';
import 'components/section-title-example.dart';
import 'components/smart-image-example.dart';

Route<dynamic>? routes(RouteSettings settings) {
  MaterialPageRoute<dynamic>? _route;
//  final GlobalKey<NavigatorState> navigatorKey =
//      new GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  Drawer _drawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.all(8),
            title: Text("Featured View"),
            onTap: () {
              Navigator.pushNamed(context, "/");
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.all(8),
            title: Text("State Document"),
            onTap: () {
              Navigator.pushNamed(context, "/state-document");
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.all(8),
            title: Text("Card Button"),
            onTap: () {
              Navigator.pushNamed(context, "/card-button");
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.all(8),
            title: Text("Language Selector"),
            onTap: () {
              Navigator.pushNamed(context, "/language-selector");
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.all(8),
            title: Text("Section Title"),
            onTap: () {
              Navigator.pushNamed(context, "/section-title");
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.all(8),
            title: Text("Smart Image"),
            onTap: () {
              Navigator.pushNamed(context, "/smart-image");
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.all(8),
            title: Text("Preview Audio"),
            onTap: () {
              Navigator.pushNamed(context, "/preview-audio");
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.all(8),
            title: Text("Flag and Status Chips"),
            onTap: () {
              Navigator.pushNamed(context, "/chips");
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.all(8),
            title: Text("Charts"),
            onTap: () {
              Navigator.pushNamed(context, "/charts");
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.all(8),
            title: Text("Invitation"),
            onTap: () {
              Navigator.pushNamed(context, "/invitation");
            },
          ),
        ],
      ),
    );
  }

  switch (settings.name) {
    case "/":
      _route = MaterialPageRoute<dynamic>(
        builder: (BuildContext context) {
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(),
            drawer: _drawer(context),
            body: FeaturedViewExample(scaffoldKey: _scaffoldKey),
          );
        },
      );
      break;
    case "/card-button":
      _route = MaterialPageRoute<dynamic>(
        builder: (BuildContext context) {
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(),
            drawer: _drawer(context),
            body: CardButtonExample(scaffoldKey: _scaffoldKey),
          );
        },
      );
      break;
    case "/language-selector":
      _route = MaterialPageRoute<dynamic>(
        builder: (BuildContext context) {
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(),
            drawer: _drawer(context),
            body: LanguageSelectorExample(scaffoldKey: _scaffoldKey),
          );
        },
      );
      break;
    case "/section-title":
      _route = MaterialPageRoute<dynamic>(
        builder: (BuildContext context) {
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(),
            drawer: _drawer(context),
            body: SectionTitleExample(scaffoldKey: _scaffoldKey),
          );
        },
      );
      break;
    case "/smart-image":
      _route = MaterialPageRoute<dynamic>(
        builder: (BuildContext context) {
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(),
            drawer: _drawer(context),
            body: SmartImageExample(scaffoldKey: _scaffoldKey),
          );
        },
      );
      break;
    case "/preview-audio":
      _route = MaterialPageRoute<dynamic>(
        builder: (BuildContext context) {
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(),
            drawer: _drawer(context),
            body: PreviewAudioExample(scaffoldKey: _scaffoldKey),
          );
        },
      );
      break;
    case "/chips":
      _route = MaterialPageRoute<dynamic>(
        builder: (BuildContext context) {
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(),
            drawer: _drawer(context),
            body: ChipsExample(scaffoldKey: _scaffoldKey),
          );
        },
      );
      break;
    case "/charts":
      _route = MaterialPageRoute<dynamic>(
        builder: (BuildContext context) {
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(),
            drawer: _drawer(context),
            body: ChartsExample(scaffoldKey: _scaffoldKey),
          );
        },
      );
      break;
    case "/invitation":
      _route = MaterialPageRoute<dynamic>(
        builder: (BuildContext context) {
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(),
            drawer: _drawer(context),
            body: InvitationExample(scaffoldKey: _scaffoldKey),
          );
        },
      );
      break;
    case "/state-document":
      _route = MaterialPageRoute<dynamic>(
        builder: (BuildContext context) {
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(),
            drawer: _drawer(context),
            body: StateDocumentDemo(scaffoldKey: _scaffoldKey),
          );
        },
      );
      break;
  }
  return _route;
}
