import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/log_color.dart';
import '../helper/route_helper.dart';
import '../placeholder/loading_screen.dart';
import '../serialized/user_status.dart';
import '../state/state_alert.dart';

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
        await widget.onInit!().then((value) {
          loading = false;
        });
      } catch (e) {
        loading = false;
        debugPrint(LogColor.error('$e'));
      }
    } else {
      loading = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    loading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _onInit();
    });
    super.initState();
  }

  @override
  void didUpdateWidget(BaseRoutePage oldWidget) {
    if (oldWidget.uri != widget.uri) {
      loading = true;
      if (mounted) setState(() {});
      _onInit();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final notReady = widget.status == null || !widget.status!.ready;
    if (loading || notReady) return widget.loading;
    final locales = AppLocalizations.of(context);
    final alert = Provider.of<StateAlert>(context, listen: false);
    alert.context = context;
    try {
      if (widget.status?.connectionChanged ?? false) {
        if (widget.status?.connected ?? false) {
          alert.show(AlertData(
            icon: Icons.wifi,
            body: locales.get('notification--you-are-back-online'),
            clear: true,
            duration: 2,
          ));
        } else {
          alert.show(AlertData(
            icon: Icons.wifi_off,
            body: locales.get('notification--you-are--offline'),
            clear: true,
            duration: 2,
            type: AlertType.warning,
          ));
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
