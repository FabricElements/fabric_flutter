import 'package:flutter/material.dart';
import 'package:fabric_flutter/components.dart';

class LanguageSelectorExample extends StatelessWidget {
  LanguageSelectorExample({Key key, @required this.scaffoldKey})
      : super(key: key);
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            SectionTitle(
              headline: "This is the Language Selector demo",
              description: "Select the language and it'll print for you!",
            ),
            Expanded(
              child: LanguageSelector(
                backgroundColor: Colors.grey.shade900,
                language: "en",
                onChange: (String iso) {
                  print("Selected language: $iso");
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
