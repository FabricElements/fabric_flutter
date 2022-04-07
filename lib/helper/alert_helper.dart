import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../component/smart_image.dart';
import 'app_localizations_delegate.dart';
import 'redirect_app.dart';

/// [AlertType] are used to defined behavior and colors for the alerts
enum AlertType {
  /// [basic] is used for simple alerts
  basic,

  /// [critical] used for errors and alerts that require an action
  critical,

  /// [success] alerts
  success,

  /// [warning] alerts
  warning,
}

/// This is an alert class, depending on the type of alert wanted a snackbar will be displayed.
/// AlertHelper(
///   context: context,
///   mounted: mounted,
/// ).show(
///   text: 'Something went wrong...',
///   type: AlertTypes.critical,
/// );
class AlertHelper {
  const AlertHelper({
    required this.context,
    required this.mounted,
  });

  final BuildContext context;
  final bool mounted;

  /// [typeFromString] returns [AlertType] from a String
  AlertType typeFromString(String? type) {
    AlertType _type = AlertType.basic;
    switch (type) {
      case 'critical':
        _type = AlertType.critical;
        break;
      case 'success':
        _type = AlertType.success;
        break;
      case 'warning':
        _type = AlertType.warning;
        break;
    }
    return _type;
  }

  /// Display Alert with [show] function
  Future<void> show({
    /// Notification [name]
    String? title,

    /// Notification [body]
    String? body,

    /// Alert [duration] in seconds
    int? duration,

    /// [type] used for the Alert
    AlertType? type,

    /// [typeString] used to return [AlertType]
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
    /// Set a localized label or 'label--continue' will be used by default
    String actionLabel = 'label--continue',

    /// [dismissCallback] defines the callback used for the dismiss button
    VoidCallback? dismissCallback,

    /// [dismissIcon] defines the Icon used for the dismiss button
    /// Icons.close is used by default
    IconData dismissIcon = Icons.close,

    /// [dismissLabel] defines the label used for the dismiss button
    /// Set a localized label or 'label--dismiss' will be used by default
    String dismissLabel = 'label--dismiss',
  }) async {
    if (!mounted) {
      if (kDebugMode) print('Called Alert when unmounted');
      return;
    }

    final queryData = MediaQuery.of(context);
    double width = queryData.size.width;
    double basePadding = 16.0;
    double contentWidth = width - (basePadding * 4);

    // int height = constraints.maxHeight.floor();
    AppLocalizations locales = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    RedirectApp redirectApp =
        RedirectApp(context: context, protected: ['/protected']);
    // await Future.delayed(Duration(microseconds: 200));
    // BuildContext parentContext = globalContext ?? context;
    ScaffoldMessenger.of(context).clearSnackBars();
    Color color = Colors.grey.shade900;
    AlertType _type = type ?? AlertType.basic;
    if (typeString != null) {
      _type = typeFromString(typeString);
    }
    if (kDebugMode) {
      print('////////// Alert: $_type ///////////');
      print(title ?? body ?? 'UNKNOWN');
      print('////////////////////////////');
    }
    int durationBaseSeconds = 10;
    int _duration = duration ?? durationBaseSeconds;
    switch (_type) {
      case AlertType.critical:
        color = Colors.red;
        _duration = duration ?? 600;
        break;
      case AlertType.warning:
        color = Colors.deepOrange;
        _duration = duration ?? 60;
        break;
      case AlertType.success:
        color = Colors.green;
        _duration = duration ?? 6;
        break;
      default:
    }
    try {
      List<Widget> _onColumn = [];
      List<Widget> _mainItems = [];

      if (image != null) {
        _mainItems.add(Container(
          margin: const EdgeInsets.only(bottom: 16),
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
          margin: const EdgeInsets.only(bottom: 8),
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
          margin: const EdgeInsets.only(bottom: 8),
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
          style: ButtonStyle(
            foregroundColor: MaterialStateProperty.all(color),
          ),
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

      if (_duration > 3) {
        _actions.add(TextButton.icon(
          icon: Icon(dismissIcon),
          label: Text(locales.get(dismissLabel).toUpperCase()),
          onPressed: () {
            if (dismissCallback != null) dismissCallback();
            ScaffoldMessenger.of(context).clearSnackBars();
          },
        ));
      }

      if (_actions.isNotEmpty) {
        _onColumn.add(Container(
          margin: const EdgeInsets.only(top: 16),
          child: Wrap(
            children: _actions,
            spacing: 16,
          ),
        ));
      }
      _mainItems.add(Column(
        children: _onColumn,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Wrap(
            direction: Axis.vertical,
            children: _mainItems,
            clipBehavior: Clip.hardEdge,
          ),
          duration: Duration(seconds: _duration),
          backgroundColor: color,
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        print('/////////////////////');
        print(error);
        print('/////////////////////');
      }
    }
  }
}
