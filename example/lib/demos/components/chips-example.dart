import 'package:fabric_flutter/component/flag_chip.dart';
import 'package:fabric_flutter/component/section_title.dart';
import 'package:fabric_flutter/component/status_chip.dart';
import 'package:fabric_flutter/component/user_avatar.dart';
import 'package:flutter/material.dart';

class ChipsExample extends StatelessWidget {
  ChipsExample({Key? key, required this.scaffoldKey}) : super(key: key);
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          children: <Widget>[
            SectionTitle(
              headline: "Flag Chip, Status Chip and Avatar Examples",
            ),
            UserAvatar(
              avatar: "https://source.unsplash.com/random",
              name: "John Doe",
            ),
            Divider(
              height: 32,
              thickness: 2,
            ),
            FlagChip(
              language: "en",
              total: 100,
            ),
            Divider(
              height: 32,
              thickness: 2,
            ),
            StatusChip(status: "draft"),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
