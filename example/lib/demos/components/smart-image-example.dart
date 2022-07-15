import 'package:fabric_flutter/component/section_title.dart';
import 'package:fabric_flutter/component/smart_image.dart';
import 'package:flutter/material.dart';

class SmartImageExample extends StatelessWidget {
  SmartImageExample({Key? key, required this.scaffoldKey}) : super(key: key);
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
              child: SmartImage(
                url: "https://source.unsplash.com/random",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
