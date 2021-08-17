import 'package:fabric_flutter/component.dart';
import 'package:flutter/material.dart';

class CardButtonExample extends StatelessWidget {
  CardButtonExample({Key? key, required this.scaffoldKey}) : super(key: key);
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: ListView(
          children: <Widget>[
            CardButton(
              image: "https://source.unsplash.com/random",
              headline: "This is the Card Button demonstration",
              description:
                  "Click me, or on the menu icon to view the other demonstrations",
              onPressed: () {
                scaffoldKey.currentState!.openDrawer();
              },
            ),
            CardButton(
              image: "https://source.unsplash.com/random",
              headline: "Click me to show an alert",
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      contentPadding: EdgeInsets.all(16),
                      title: Text("Informative Alert Dialog"),
                      actions: <Widget>[
                        ElevatedButton(
                          child: Text("DISMISS"),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
