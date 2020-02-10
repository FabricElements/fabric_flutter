import 'package:fabric_flutter/components.dart';
import 'package:flutter/material.dart';

class SmartImageExample extends StatelessWidget {
  SmartImageExample({Key key, @required this.scaffoldKey}) : super(key: key);
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            SectionTitle(
              headline: "This is the Smart Image demo",
            ),
            Expanded(
              child: SmartImgix(
                image: "https://source.unsplash.com/random",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
