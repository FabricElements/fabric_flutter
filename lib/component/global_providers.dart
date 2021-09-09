import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../state/state_analytics.dart';
import '../state/state_api.dart';
import '../state/state_document.dart';
import '../state/state_dynamic_links.dart';
import '../state/state_global.dart';
import '../state/state_notifications.dart';
import '../state/state_user.dart';

class GlobalProviders extends StatelessWidget {
  const GlobalProviders({
    Key? key,
    required this.child,
    required this.providers,
  }) : super(key: key);

  final Widget child;
  final List<SingleChildWidget>? providers;

  @override
  Widget build(BuildContext context) {
    List<SingleChildWidget> _providers = providers ?? [];
    _providers.addAll([
      ChangeNotifierProvider(create: (context) => StateAnalytics()),
      ChangeNotifierProvider(create: (context) => StateAPI()),
      ChangeNotifierProvider(create: (context) => StateDocument()),
      ChangeNotifierProvider(create: (context) => StateDynamicLinks()),
      ChangeNotifierProvider(create: (context) => StateGlobal()),
      ChangeNotifierProvider(create: (context) => StateNotifications()),
      ChangeNotifierProvider(create: (context) => StateUser()),
    ]);
    return MultiProvider(
      providers: _providers,
      child: child,
    );
  }
}
