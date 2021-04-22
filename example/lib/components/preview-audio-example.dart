import 'package:fabric_flutter/components.dart';
import 'package:flutter/material.dart';

class PreviewAudioExample extends StatelessWidget {
  PreviewAudioExample({Key key, @required this.scaffoldKey}) : super(key: key);
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
            Column(
              children: [
                AudioPreview(
                  url:
                      "https://file-examples-com.github.io/uploads/2017/11/file_example_MP3_700KB.mp3",
                  loadingText: "Loading...",
                ),
                ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text("Back")),
                ElevatedButton(
                    onPressed: () => Navigator.of(context).popAndPushNamed("/"),
                    child: Text("other view")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
