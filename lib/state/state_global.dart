import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Holds application-wide environment and connectivity state.
///
/// This notifier is intended to be initialized once near app startup. Widgets
/// can listen to it for package metadata, account changes, and connectivity
/// transitions. Updates propagate through [notifyListeners] and the dedicated
/// [streamConnection] stream so UI code can either rebuild declaratively or
/// react imperatively to connection changes.
class StateGlobal extends ChangeNotifier {
  /// Creates the global application state holder.
  StateGlobal();

  /// Stores package metadata loaded from the current platform.
  PackageInfo? _packageInfo;

  /// Returns the current [PackageInfo], or an empty placeholder before
  /// initialization finishes.
  ///
  /// Returning a fallback object avoids null checks throughout the UI while the
  /// asynchronous platform lookup is still in flight.
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

  /// Loads package metadata from the underlying platform.
  ///
  /// Errors are ignored because test environments and some nonstandard runners
  /// may not expose package information.
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

  /// Returns the formatted application version string.
  ///
  /// The result looks like `v1.2.3+45` when both version and build number are
  /// available, or `null` until version metadata has been loaded.
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

  /// Stores the active account identifier.
  String? _account;

  /// Returns the active account identifier.
  String? get account => _account;

  /// Updates the active account identifier and notifies listeners.
  set account(String? value) {
    if (value == _account) return;
    _account = value;
    notifyListeners();
  }

  /// Broadcasts connectivity changes for consumers that prefer stream-style
  /// reactions.
  ///
  /// ignore: close_sinks
  final _controllerStreamConnection = StreamController<bool>.broadcast();

  /// Emits `true` when connectivity is restored and `false` when it is lost.
  Stream<bool> get streamConnection => _controllerStreamConnection.stream;

  /// Tracks whether the device is currently connected to a network.
  bool connected = true;

  /// Stores the current connectivity transport name, such as `wifi` or
  /// `mobile`.
  String? connectedTo;

  /// Starts listening for connectivity changes.
  ///
  /// The listener coalesces repeated transport reports and only notifies when
  /// the effective online/offline state changes, which prevents unnecessary UI
  /// churn while platform plugins emit intermediate updates.
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

  /// Initializes package and connectivity state.
  ///
  /// Call this once near application startup before widgets begin reading the
  /// notifier.
  void init() {
    WidgetsFlutterBinding.ensureInitialized();
    _initPackageInfo();
    _initConnectivity();
  }
}
