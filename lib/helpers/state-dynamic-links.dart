import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// This is a change notifier class which keeps track of state within the dynamic links.
class StateDynamicLinks extends ChangeNotifier {
  StateDynamicLinks();

  bool _initialized = false;
  Future<void> Function(PendingDynamicLinkData dynamicLink) _callback;

  set callback(
      Future<void> Function(PendingDynamicLinkData dynamicLink) callback) {
    _callback = callback;
  }

  void init() async {
    try {
      if (_initialized) {
        return;
      }
      FirebaseDynamicLinks.instance.onLink(
          onSuccess: (PendingDynamicLinkData dynamicLink) async {
        this._callback(dynamicLink);
      }, onError: (OnLinkErrorException e) async {
        print("Dynamic link error: ${e.message}");
      });
      final PendingDynamicLinkData dynamicLink =
          await FirebaseDynamicLinks.instance.getInitialLink();
      if (dynamicLink?.link != null) {
        this._callback(dynamicLink);
      }
      _initialized = true;
    } catch (error) {
      print("dynamic link: $error");
    }
  }
}
