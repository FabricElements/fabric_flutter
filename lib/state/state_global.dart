import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

bool kIsTest = (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

/// This is a change notifier class which keeps track of state within the widgets.
class StateGlobal extends ChangeNotifier {
  StateGlobal();

  /// More at [packageInfo]
  PackageInfo? _packageInfo;

  /// packageInfo returns [PackageInfo] temporal or final data
  PackageInfo get packageInfo {
    if (_packageInfo == null) {
      WidgetsFlutterBinding.ensureInitialized();
      PackageInfo.fromPlatform().then((value) {
        _packageInfo = value;
        Future.delayed(const Duration(seconds: 1))
            .then((value) => notifyListeners());
      }).catchError((e) {
        debugPrint('PackageInfo Error: $e');
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
}
