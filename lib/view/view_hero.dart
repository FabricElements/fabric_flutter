import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/state_user.dart';

class ViewHero extends StatefulWidget {
  const ViewHero({Key? key}) : super(key: key);

  @override
  State<ViewHero> createState() => _ViewHeroState();
}

class _ViewHeroState extends State<ViewHero> {
  @override
  Widget build(BuildContext context) {
    final stateUser = Provider.of<StateUser>(context);
    stateUser.ping('view-hero');
    final args = Map.from(
        ModalRoute.of(context)!.settings.arguments as Map<dynamic, dynamic>? ??
            {});
    String? mediaUrl = args['url'];
    Widget _content = const Padding(
      padding: EdgeInsets.all(16),
      child: Text('Your media file can\'t be loaded'),
    );
    if (mediaUrl != null) {
      _content = SizedBox.expand(
        child: Hero(
          tag: 'hero-media',
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(16),
            child: Image.network(
              mediaUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
      ),
      body: _content,
    );
  }
}
