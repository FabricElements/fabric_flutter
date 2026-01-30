import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
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

  /// Initialize package info
  void _initPackageInfo() {
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
    if (value == _account) return;
    _account = value;
    notifyListeners();
  }

  /// Internet connection status
  /// More at [streamSerialized]
  /// ignore: close_sinks
  final _controllerStreamConnection = StreamController<bool>.broadcast();

  /// Stream Connection
  Stream<bool> get streamConnection => _controllerStreamConnection.stream;
  bool connected = true;
  String? connectedTo;

  /// Initialize connectivity listener
  void _initConnectivity() {
    /// Check connectivity
    try {
      Connectivity().onConnectivityChanged.listen(
        (results) async {
          if (results.firstOrNull?.name != connectedTo) {
            ConnectivityResult connectivityStatus = ConnectivityResult.none;
            if (results.contains(ConnectivityResult.wifi)) {
              connectivityStatus = ConnectivityResult.wifi;
            } else if (results.contains(ConnectivityResult.ethernet)) {
              connectivityStatus = ConnectivityResult.ethernet;
            } else if (results.contains(ConnectivityResult.mobile)) {
              connectivityStatus = ConnectivityResult.mobile;
            } else if (results.contains(ConnectivityResult.other)) {
              connectivityStatus = ConnectivityResult.other;
            }
            final connectedUpdated =
                connectivityStatus != ConnectivityResult.none;
            bool connectionChanged = connected != connectedUpdated;
            connected = connectedUpdated;
            connectedTo = connectivityStatus.name;
            if (connectionChanged) {
              _controllerStreamConnection.sink.add(connected);
              connectionChanged = false;
              notifyListeners();
            }
          }
        },
        cancelOnError: true,
        onError: (error) {
          debugPrint('Connectivity error: ${error.toString()}');
        },
      );
    } catch (error) {
      debugPrint('Connectivity error: ${error.toString()}');
    }
  }

  /// Initialize the state
  void init() {
    WidgetsFlutterBinding.ensureInitialized();
    _initPackageInfo();
    _initConnectivity();
  }
}
