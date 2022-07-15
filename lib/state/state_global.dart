library fabric_flutter;

import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// This is a change notifier class which keeps track of state within the widgets.
class StateGlobal extends ChangeNotifier {
  StateGlobal();

  /// More at [packageInfo]
  PackageInfo? _packageInfo;

  /// [packageInfo] returns [PackageInfo] temporal or final data
  PackageInfo get packageInfo {
    if (_packageInfo == null) {
      PackageInfo.fromPlatform().then((value) {
        _packageInfo = value;
        Future.delayed(const Duration(seconds: 1))
            .then((value) => notifyListeners());
      });
      return PackageInfo(
        appName: 'Unknown',
        packageName: 'Unknown',
        version: 'Unknown',
        buildNumber: 'Unknown',
        buildSignature: 'Unknown',
      );
    }
    return _packageInfo!;
  }
}
