import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// This is a change notifier class which keeps track of state within the widgets.
class StateGlobal extends ChangeNotifier {
  StateGlobal();

  /// More at [packageInfo]
  PackageInfo? _packageInfo;

  /// packageInfo returns [PackageInfo] temporal or final data
  PackageInfo get packageInfo {
    if (_packageInfo == null) {
      WidgetsFlutterBinding.ensureInitialized();
      PackageInfo.fromPlatform()
          .then((value) {
            _packageInfo = value;
            Future.delayed(
              const Duration(seconds: 1),
            ).then((value) => notifyListeners());
          })
          .catchError((e) {
            // Ignore error, it's usually an issue with the test environment
          });
      return PackageInfo(
        appName: '',
        packageName: '',
        version: '',
        buildNumber: '',
        buildSignature: '',
      );
    }
    return _packageInfo!;
  }

  /// Return app version as a string
  String? get appVersion {
    String finalVersion = '';
    if (packageInfo.version.isNotEmpty) {
      finalVersion += 'v';
      finalVersion += packageInfo.version;
      if (packageInfo.buildNumber.isNotEmpty) {
        finalVersion += '+';
        finalVersion += packageInfo.buildNumber;
      }
    }
    if (finalVersion.isEmpty) return null;
    return finalVersion;
  }

  /// Current Account ID
  String? _account;

  /// Current Account ID
  String? get account => _account;

  /// Current Account ID
  set account(String? value) {
    _account = value;
    notifyListeners();
  }
}
