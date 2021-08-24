import 'package:flutter/material.dart';

class ViewHero extends StatefulWidget {
  @override
  _ViewHeroState createState() => _ViewHeroState();
}

class _ViewHeroState extends State<ViewHero> {
  @override
  Widget build(BuildContext context) {
    final args = Map.from(
        ModalRoute.of(context)!.settings.arguments as Map<dynamic, dynamic>? ??
            {});
    String? mediaUrl = args["url"] ?? null;
    Widget _content = Padding(
      padding: EdgeInsets.all(16),
      child: Text("Your media file can't be loaded"),
    );
    if (mediaUrl != null) {
      _content = SizedBox.expand(
        child: Hero(
          tag: "hero-media",
          child: Image.network(
            mediaUrl,
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(),
      body: _content,
    );
  }
}
