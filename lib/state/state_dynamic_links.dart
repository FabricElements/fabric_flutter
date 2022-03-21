import 'dart:async';

import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart';

/// This is a change notifier class which keeps track of state within the dynamic links.
class StateDynamicLinks extends ChangeNotifier {
  StateDynamicLinks();

  /// The functions was initialized
  bool _initialized = false;

  /// More at [callback]
  late Future<void> Function(PendingDynamicLinkData? dynamicLink) _callback;

  /// Define callback function
  set callback(
      Future<void> Function(PendingDynamicLinkData? dynamicLink) callback) {
    _callback = callback;
  }

  /// Init Dynamic Links
  void init() async {
    if (kIsWeb) return;
    try {
      await Future.delayed(const Duration(seconds: 3));
      if (_initialized) {
        return;
      }
      FirebaseDynamicLinks dynamicLinks = FirebaseDynamicLinks.instance;
      dynamicLinks.onLink.listen((dynamicLinkData) async {
        final Uri? deepLink = dynamicLinkData.link;
        String linkString = deepLink.toString();
        if (kDebugMode) print('onLink: $linkString');
        _callback(dynamicLinkData);
      }).onError((e) async {
        if (kDebugMode) print('Dynamic link error: ${e.message}');
      });
      final PendingDynamicLinkData? dynamicLink =
          await FirebaseDynamicLinks.instance.getInitialLink();
      if (dynamicLink?.link != null) {
        final Uri? deepLink = dynamicLink?.link;
        String linkString = deepLink.toString();
        if (kDebugMode) print('InitialLink: $linkString');
        _callback(dynamicLink);
      }
      _initialized = true;
    } catch (error) {
      if (kDebugMode) print('dynamic link: $error');
    }
  }
}
