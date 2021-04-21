import 'package:flutter/material.dart';
import 'package:fabric_flutter/components.dart';

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
            Center(
              child: AudioPreview(
                url: "https://file-examples-com.github.io/uploads/2017/11/file_example_MP3_700KB.mp3",
                loadingText: "Loading...",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
