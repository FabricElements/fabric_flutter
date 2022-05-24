import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// This is a change notifier class which keeps track of state within the widgets.
class StateGlobal extends ChangeNotifier {
  StateGlobal();

  /// More at [packageInfo]
  PackageInfo? _packageInfo;

  /// Gets [PackageInfo] data
  Future<void> _getPackageInfo() async {
    if (_packageInfo != null) return;
    _packageInfo = await PackageInfo.fromPlatform();
    // await Future.delayed(Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      notifyListeners();
    });
  }

  /// [packageInfo] returns [PackageInfo] temporal or final data
  PackageInfo get packageInfo {
    if (_packageInfo == null) {
      _getPackageInfo();
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
