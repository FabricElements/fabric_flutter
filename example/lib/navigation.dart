import 'package:flutter/material.dart';

Route<dynamic> routes(RouteSettings settings) {
  MaterialPageRoute<dynamic> _route;
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
            body: Text("Hello"),
          );
        },
      );
      break;
  }
  return _route;
}
