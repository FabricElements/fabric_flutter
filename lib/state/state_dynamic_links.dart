import 'dart:async';

import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart';

import '../helper/log_color.dart';

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

  PendingDynamicLinkData? pendingDynamicLinkData;

  /// Init Dynamic Links
  void init() async {
    try {
      await Future.delayed(const Duration(seconds: 3));
      if (_initialized) {
        return;
      }
      final dynamicLinks = FirebaseDynamicLinks.instance;
      final dynamicLink = await dynamicLinks.getInitialLink();
      if (dynamicLink?.link != null) {
        final Uri? deepLink = dynamicLink?.link;
        String linkString = deepLink.toString();
        debugPrint(LogColor.info('InitialLink: $linkString'));
        _callback(dynamicLink);
      }
      dynamicLinks.onLink.listen((dynamicLinkData) async {
        pendingDynamicLinkData = dynamicLinkData;
        if (_initialized) notifyListeners();
        final deepLink = dynamicLinkData.link;
        final linkString = deepLink.toString();
        debugPrint(LogColor.info('onLink: $linkString'));
        _callback(dynamicLinkData);
      }).onError((e) async {
        debugPrint(LogColor.error('Dynamic link error: ${e.message}'));
      });
      _initialized = true;
    } catch (error) {
      debugPrint('dynamic link: $error');
    }
  }
}
