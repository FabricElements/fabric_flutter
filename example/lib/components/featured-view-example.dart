import 'package:flutter/material.dart';
import 'package:fabric_flutter/components.dart';

class FeaturedViewExample extends StatelessWidget {
  FeaturedViewExample({Key? key, required this.scaffoldKey}) : super(key: key);
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FeaturedView(
        image: "https://source.unsplash.com/random",
        headline: "This is the Featured View demonstration",
        description:
            "Click the button, or on the menu icon to view the other demonstrations",
        actionLabel: "CLICK TO OPEN THE COMPONENTS DRAWER",
        onPressed: () {
          scaffoldKey.currentState!.openDrawer();
        },
        firstGradientAnimationColor: Colors.grey.shade900,
        secondGradientAnimationColor: Colors.grey.shade900,
        thirdGradientAnimationColor: Colors.grey.shade900,
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
