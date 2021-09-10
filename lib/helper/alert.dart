import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../component/smart_image.dart';
import 'app_localizations_delegate.dart';
import 'redirect_app.dart';

/// [AlertTypes] are used to defined behavior and colors for the alerts
enum AlertTypes {
  /// [basic] is used for the most basic alert
  basic,

  /// [critical]
  critical,

  /// [success]
  success,

  /// [warning]
  warning,
}

/// This is an alert class, depending on the type of alert wanted a snackbar will be displayed.
/// Alert(
///   context: context,
///   mounted: mounted,
/// ).show(
///   text: "Something went wrong...",
///   type: AlertTypes.critical,
/// );
class Alert {
  const Alert({
    required this.context,
    required this.mounted,
  });

  final BuildContext context;
  final bool mounted;

  /// [typeFromString] returns [AlertTypes] from a String
  AlertTypes typeFromString(String? type) {
    AlertTypes _type = AlertTypes.basic;
    switch (type) {
      case "critical":
        _type = AlertTypes.critical;
        break;
      case "success":
        _type = AlertTypes.success;
        break;
      case "warning":
        _type = AlertTypes.warning;
        break;
    }
    return _type;
  }

  /// Display Alert with [show] function
  Future<void> show({
    /// Notification [title]
    String? title,

    /// Notification [body]
    String? body,

    /// Alert [duration] in seconds
    int? duration,

    /// [type] used for the Alert
    AlertTypes? type,

    /// [typeString] used to return [AlertTypes]
    String? typeString,

    /// [path] to redirect
    String? path,

    /// [image] URL
    String? image,

    /// Redirect [arguments]
    Map<String, dynamic>? arguments,

    /// [actionCallback] defines the callback used for the action button
    VoidCallback? actionCallback,

    /// [actionIcon] defines the Icon used for the action button
    /// Icons.navigate_next is used by default
    IconData actionIcon = Icons.navigate_next,

    /// [actionLabel] defines the label used for the action button
    /// Set a localized label or "label--continue" will be used by default
    String actionLabel = "label--continue",

    /// [dismissCallback] defines the callback used for the dismiss button
    VoidCallback? dismissCallback,

    /// [dismissIcon] defines the Icon used for the dismiss button
    /// Icons.close is used by default
    IconData dismissIcon = Icons.close,

    /// [dismissLabel] defines the label used for the dismiss button
    /// Set a localized label or "label--dismiss" will be used by default
    String dismissLabel = "label--dismiss",
  }) async {
    if (!mounted) {
      print("Called Alert when unmounted");
      return;
    }
    // String actionLabel = actionLabel ?? "label--continue";
    // IconData actionIcon = actionIcon ?? Icons.navigate_next;

    // String dismissLabel = dismissLabel ?? "label--dismiss";
    // IconData dismissIcon = dismissIcon ?? Icons.close;

    final queryData = MediaQuery.of(context);
    double width = queryData.size.width;
    double basePadding = 16.0;
    double contentWidth = width - (basePadding * 4);

    // int height = constraints.maxHeight.floor();
    AppLocalizations locales = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    RedirectApp redirectApp =
        RedirectApp(context: context, protected: ["/protected"]);
    // await Future.delayed(Duration(microseconds: 200));
    // BuildContext parentContext = globalContext ?? context;
    ScaffoldMessenger.of(context).clearSnackBars();
    Color color = Colors.grey.shade800;
    AlertTypes _type = type ?? AlertTypes.basic;
    if (typeString != null) {
      _type = typeFromString(typeString);
    }
    if (kDebugMode) {
      print("////////// Alert: $_type ///////////");
      print(title ?? body ?? "UNKNOWN");
      print("////////////////////////////");
    }
    int durationBaseSeconds = 10;
    int _duration = duration ?? durationBaseSeconds;
    switch (_type) {
      case AlertTypes.critical:
        color = Colors.red;
        _duration = duration ?? 600;
        break;
      case AlertTypes.warning:
        color = Colors.orange;
        _duration = duration ?? 60;
        break;
      case AlertTypes.success:
        color = Colors.green;
        _duration = duration ?? 6;
        break;
      default:
        color = Colors.grey.shade800;
    }
    try {
      // image =
      //     "https://images.unsplash.com/photo-1504297050568-910d24c426d3?ixid=MnwxMjA3fDF8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&ixlib=rb-1.2.1&auto=format&fit=crop&w=668&q=80";
      List<Widget> _onColumn = [];
      List<Widget> _mainItems = [];

      if (image != null) {
        _mainItems.add(Container(
          margin: EdgeInsets.only(bottom: 16),
          constraints: BoxConstraints(
              minHeight: 50, maxHeight: 400, maxWidth: contentWidth),
          color: Colors.grey.shade900,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: SmartImage(url: image),
          ),
        ));
      }
      if (title != null) {
        _onColumn.add(Container(
          constraints: BoxConstraints(minWidth: 50, maxWidth: contentWidth),
          margin: EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: textTheme.headline5?.apply(color: Colors.white),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ));
      }
      if (body != null) {
        _onColumn.add(Container(
          constraints: BoxConstraints(minWidth: 50, maxWidth: contentWidth),
          margin: EdgeInsets.only(bottom: 8),
          child: Text(
            body,
            style: textTheme.bodyText1?.apply(color: Colors.grey.shade50),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ));
      }
      List<Widget> _actions = [];
      bool hasAction =
          (path != null && path.isNotEmpty) || actionCallback != null;
      if (hasAction) {
        _actions.add(ElevatedButton.icon(
          label: Text(locales.get(actionLabel).toUpperCase()),
          icon: Icon(actionIcon),
          onPressed: () {
            if (path != null && path.isNotEmpty) {
              redirectApp.toView(
                path: path,
                arguments: arguments,
              );
            }
            if (actionCallback != null) actionCallback();
            ScaffoldMessenger.of(context).clearSnackBars();
          },
        ));
      }
      _actions.add(TextButton.icon(
        icon: Icon(dismissIcon),
        label: Text(locales.get(dismissLabel).toUpperCase()),
        onPressed: () {
          if (dismissCallback != null) dismissCallback();
          ScaffoldMessenger.of(context).clearSnackBars();
        },
      ));
      _onColumn.add(Container(
        margin: EdgeInsets.only(top: 16),
        child: Wrap(
          children: _actions,
          spacing: 16,
        ),
      ));
      _mainItems.add(Column(
        children: _onColumn,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: SafeArea(
            top: false,
            left: false,
            right: false,
            child: Wrap(
              direction: Axis.vertical,
              children: _mainItems,
              clipBehavior: Clip.hardEdge,
            ),
          ),
          duration: Duration(seconds: _duration),
          backgroundColor: color,
        ),
      );
    } catch (error) {
      print("/////////////////////");
      print(error);
      print("/////////////////////");
    }
  }
}
