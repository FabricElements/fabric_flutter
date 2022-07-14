import 'package:fabric_flutter/component/language_selector.dart';
import 'package:fabric_flutter/component/section_title.dart';
import 'package:flutter/material.dart';

class LanguageSelectorExample extends StatelessWidget {
  LanguageSelectorExample({Key? key, required this.scaffoldKey})
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
