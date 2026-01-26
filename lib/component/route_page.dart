import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/log_color.dart';
import '../helper/route_helper.dart';
import '../placeholder/loading_screen.dart';
import '../serialized/user_status.dart';
import 'alert_data.dart';

/// BaseRoutePage
/// Use it to structure your route page class.
/// Extends [StatefulWidget]
abstract class BaseRoutePage extends StatefulWidget {
  const BaseRoutePage({
    super.key,
    required this.routeHelper,
    required this.uri,
    required this.status,
    this.loading = const LoadingScreen(),
    this.onInit,
  });

  final RouteHelper routeHelper;
  final Uri uri;
  final UserStatus? status;
  final Widget loading;
  final Function? onInit;
}

/// BaseRoutePageState
/// Use it to structure your route page state class.
abstract class BaseRoutePageState extends State<BaseRoutePage> {
  /// loading state variable
  /// Use it to show loading screen.
  /// Default is true.
  bool loading = true;

  /// onInit
  /// Use it to initialize your route page.
  /// It will be called after the first frame.
  void _onInit() async {
    if (widget.onInit != null) {
      try {
        await widget.onInit!();
      } catch (e) {
        debugPrint(LogColor.error('$e'));
      } finally {
        // Wait for all streams to cancel and complete animation
        await Future.delayed(const Duration(milliseconds: 300));
        loading = false;
      }
    } else {
      loading = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loading = true;
    _onInit();
  }

  @override
  Widget build(BuildContext context) {
    final notReady = widget.status == null || !widget.status!.ready;
    if (loading || notReady) return widget.loading;
    final locales = AppLocalizations.of(context);

    try {
      if (widget.status?.connectionChanged ?? false) {
        if (widget.status?.connected ?? false) {
          alertData(
            context: context,
            icon: Icons.wifi,
            body: locales.get('notification--you-are-back-online'),
            clear: true,
            duration: 2,
          );
        } else {
          alertData(
            context: context,
            icon: Icons.wifi_off,
            body: locales.get('notification--you-are--offline'),
            clear: true,
            duration: 2,
            type: AlertType.warning,
          );
        }
      }
    } catch (e) {
      //
    }

    Map<String, Widget> routes = widget.routeHelper.routes(
      signed: widget.status!.signedIn,
      isAdmin: widget.status!.admin,
    );
    if (routes.containsKey(widget.uri.path)) {
      return routes[widget.uri.path]!;
    }
    return routes[widget.routeHelper.unknownRoute]!;
  }
}

class RoutePage extends BaseRoutePage {
  const RoutePage({
    super.key,
    required super.routeHelper,
    required super.uri,
    required super.status,
    super.loading = const LoadingScreen(),
    super.onInit,
  });

  @override
  State<BaseRoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends BaseRoutePageState {}
