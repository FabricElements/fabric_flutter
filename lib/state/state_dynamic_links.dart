import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// This is a change notifier class which keeps track of state within the dynamic links.
class StateDynamicLinks extends ChangeNotifier {
  StateDynamicLinks();

  bool _initialized = false;
  late Future<void> Function(PendingDynamicLinkData? dynamicLink) _callback;

  set callback(
      Future<void> Function(PendingDynamicLinkData? dynamicLink) callback) {
    _callback = callback;
  }

  void init() async {
    if (kIsWeb) return;
    try {
      await Future.delayed(Duration(seconds: 3));
      if (_initialized) {
        return;
      }
      FirebaseDynamicLinks.instance.onLink(
          onSuccess: (PendingDynamicLinkData? dynamicLink) async {
        final Uri? deepLink = dynamicLink?.link;
        String linkString = deepLink.toString();
        print("onLink: $linkString");
        this._callback(dynamicLink);
      }, onError: (OnLinkErrorException e) async {
        print("Dynamic link error: ${e.message}");
      });
      final PendingDynamicLinkData? dynamicLink =
          await FirebaseDynamicLinks.instance.getInitialLink();
      if (dynamicLink?.link != null) {
        final Uri? deepLink = dynamicLink?.link;
        String linkString = deepLink.toString();
        print("InitialLink: $linkString");
        this._callback(dynamicLink);
      }
      _initialized = true;
    } catch (error) {
      print("dynamic link: $error");
    }
  }
}
