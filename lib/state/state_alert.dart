import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../component/smart_image.dart';
import '../helper/app_localizations_delegate.dart';
import '../helper/log_color.dart';
import '../helper/options.dart';
import '../helper/utils.dart';

/// AlertType are used to defined behavior and colors for the alerts
enum AlertType {
  /// basic is used for simple alerts
  basic,

  /// critical used for errors and alerts that require an action
  critical,

  /// success alerts
  success,

  /// warning alerts
  warning,
}

/// AlertWidget are used to defined behavior and colors for the alerts
enum AlertWidget {
  snackBar,
  banner,
  dialog,
}

/// Alert Data Object
class AlertData {
  /// Notification title
  final String? title;

  /// Notification body
  final String? body;

  /// Alert duration in seconds
  int? duration;

  /// type used for the Alert
  AlertType type;

  /// AlertWidget changes the type of widget used for the alert
  final AlertWidget widget;

  /// typeString used to return [AlertType]
  final String? typeString;

  /// Image URL
  final String? image;

  ButtonOptions? action;
  ButtonOptions? dismiss;
  Color? color;
  TextStyle? titleStyle;
  TextStyle? bodyStyle;
  Color? textColor;
  Widget? child;

  /// Clear all other alerts of the same type
  /// Not recommended for AlertWidget.dialog because it uses Navigator.pop(context!)
  /// and it can affect the navigation
  bool clear;

  /// Scrollable content for [AlertWidget.dialog] using [AlertDialog]
  bool scrollable;
  IconData? icon;

  AlertData({
    this.action,
    this.dismiss,
    this.title,
    this.body,
    this.duration,
    this.type = AlertType.basic,
    this.widget = AlertWidget.snackBar,
    this.typeString,
    this.icon,
    this.image,
    this.color,
    this.textColor,
    this.titleStyle,
    this.bodyStyle,
    this.clear = false,
    this.scrollable = false,
    this.child,
  });
}

class StateAlert implements Listenable {
  StateAlert();

  // Include the context to display alerts
  // StateAlert.context = use the context from the widget or [RoutePage]
  // will provide the context
  BuildContext? context;

  /// typeFromString returns AlertType from a String
  AlertType typeFromString(String? value) {
    AlertType type = AlertType.basic;
    switch (value) {
      case 'critical':
        type = AlertType.critical;
        break;
      case 'success':
        type = AlertType.success;
        break;
      case 'warning':
        type = AlertType.warning;
        break;
      default:
        type = AlertType.basic;
    }
    return type;
  }

  /// Dismiss action
  /// Dismiss current alert or all alerts with the same widget type
  void dismissAlerts({
    bool dismissAll = false,
    required AlertWidget widget,
  }) {
    if (context == null) return;
    switch (widget) {
      case AlertWidget.banner:
        if (dismissAll) {
          ScaffoldMessenger.of(context!).clearMaterialBanners();
        } else {
          ScaffoldMessenger.of(context!).removeCurrentMaterialBanner();
        }
        break;
      case AlertWidget.snackBar:
        if (dismissAll) {
          ScaffoldMessenger.of(context!).clearSnackBars();
        } else {
          ScaffoldMessenger.of(context!).removeCurrentSnackBar();
        }
        break;
      case AlertWidget.dialog:
        Navigator.pop(context!);
        break;
    }
  }

  /// Display Alert with this function
  Future<void> show(AlertData alertData) async {
    if (alertData.typeString != null) {
      alertData.type = typeFromString(alertData.typeString);
    }
    if (kDebugMode) {
      String debugMessagePrint =
          '////////// Alert: ${alertData.type} ///////////';
      if (alertData.title != null) debugMessagePrint += '\n${alertData.title}';
      if (alertData.body != null) debugMessagePrint += '\n${alertData.body}';
      if (context == null) debugMessagePrint += '\nContext is null ****';
      debugMessagePrint += '\n////////////////////////////';
      print(debugMessagePrint);
    }
    if (context == null) return;
    final queryData = MediaQuery.of(context!);
    double width = queryData.size.width;
    double basePadding = 16;
    double contentWidth = width - (basePadding * 4);
    final locales = AppLocalizations.of(context!);
    final theme = Theme.of(context!);
    final textTheme = theme.textTheme;

    Color buttonColor = theme.colorScheme.primary;
    Color buttonColorForeground = theme.colorScheme.onPrimary;
    switch (alertData.type) {
      case AlertType.critical:
        alertData.color = theme.colorScheme.error;
        alertData.textColor = theme.colorScheme.onError;
        alertData.duration ??= 15;
        buttonColor = theme.colorScheme.errorContainer;
        buttonColorForeground = theme.colorScheme.onErrorContainer;
        break;
      case AlertType.warning:
        alertData.duration ??= 15;
        buttonColor = theme.colorScheme.error;
        buttonColorForeground = theme.colorScheme.onError;
        break;
      case AlertType.success:
        alertData.color = theme.colorScheme.primaryContainer;
        alertData.textColor = theme.colorScheme.onPrimaryContainer;
        alertData.duration ??= 5;
        buttonColor = theme.colorScheme.primary;
        buttonColorForeground = theme.colorScheme.onPrimary;
        break;
      default:
    }

    /// Set default values for null safety
    alertData.duration ??= 4;
    alertData.color ??= theme.colorScheme.surfaceVariant;
    alertData.textColor ??= theme.colorScheme.onSurfaceVariant;
    alertData.titleStyle ??= textTheme.titleLarge;
    alertData.bodyStyle ??= textTheme.bodyLarge;

    alertData.titleStyle = alertData.titleStyle?.apply(
      color: alertData.textColor,
    );
    alertData.bodyStyle = alertData.bodyStyle?.apply(
      color: alertData.textColor,
    );

    /// Dismiss
    alertData.dismiss ??= ButtonOptions();
    alertData.dismiss!.icon ??= Icons.close;
    if (alertData.dismiss!.label.isEmpty) {
      alertData.dismiss!.label = 'label--dismiss';
    }

    /// Action
    alertData.action ??= ButtonOptions();
    alertData.action!.icon ??= Icons.navigate_next;
    if (alertData.action!.label.isEmpty) {
      alertData.action!.label = 'label--continue';
    }

    /// Hide all alerts from same type to prevent overlap
    if (alertData.clear) {
      await Future.delayed(const Duration(milliseconds: 500));
      dismissAlerts(dismissAll: true, widget: alertData.widget);
    }

    List<Widget> onColumn = [];
    List<Widget> mainItems = [];

    /// Title
    if (alertData.title != null) {
      onColumn.add(Container(
        constraints: BoxConstraints(minWidth: 50, maxWidth: contentWidth),
        margin: const EdgeInsets.only(bottom: 8),
        child: RawMaterialButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: alertData.title!));
          },
          child: Text(
            alertData.title!,
            style: alertData.titleStyle,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
      ));
    }
    if (alertData.body != null) {
      onColumn.add(Container(
        constraints: BoxConstraints(minWidth: 50, maxWidth: contentWidth),
        margin: const EdgeInsets.only(bottom: 8),
        child: RawMaterialButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: alertData.body!));
          },
          child: Text(
            alertData.body!,
            style: alertData.bodyStyle,
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
      ));
    }

    /// Image
    if (alertData.icon != null) {
      mainItems.add(Container(
        margin: const EdgeInsets.only(bottom: 16),
        width: double.maxFinite,
        height: 48,
        color: alertData.color,
        child: Align(
          alignment: Alignment.centerLeft,
          child: AspectRatio(
            aspectRatio: 1 / 1,
            child: CircleAvatar(
              backgroundColor: buttonColor,
              child: Icon(
                alertData.icon,
                color: buttonColorForeground,
              ),
            ),
          ),
        ),
      ));
    }

    /// Image
    if (alertData.image != null) {
      mainItems.add(Container(
        margin: const EdgeInsets.only(bottom: 16),
        width: double.maxFinite,
        height: 200,
        constraints: const BoxConstraints(
          minHeight: 50,
          minWidth: 50,
          maxHeight: 300,
          maxWidth: double.maxFinite,
        ),
        color: alertData.color,
        child: AspectRatio(
          aspectRatio: 3 / 1,
          child: SmartImage(
            url: alertData.image!,
            format: AvailableOutputFormats.jpeg,
          ),
        ),
      ));
    }

    /// Add child widget before actions
    if (alertData.child != null) {
      onColumn.add(Container(
        margin: const EdgeInsets.only(bottom: 16, top: 16),
        constraints: BoxConstraints(
          minHeight: 50,
          maxHeight: 900,
          maxWidth: contentWidth,
        ),
        child: alertData.child!,
      ));
    }

    /// Actions
    List<Widget> actions = [];
    bool hasValidPath =
        alertData.action!.path != null && alertData.action!.path!.isNotEmpty;
    bool hasAction = alertData.action!.onTap != null;
    bool showAction = hasAction || hasValidPath;
    bool hasDismissAction = alertData.dismiss!.onTap != null;
    actions.add(TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: buttonColor),
      icon: Icon(alertData.dismiss!.icon!),
      label: Text(locales.get(alertData.dismiss!.label).toUpperCase()),
      onPressed: () async {
        try {
          if (hasDismissAction) {
            await alertData.dismiss!.onTap!();
          }
          dismissAlerts(widget: alertData.widget);
        } catch (e) {
          debugPrint(LogColor.error('Dismiss click: $e'));
        }
      },
    ));
    if (showAction) {
      actions.add(FilledButton.icon(
        style: FilledButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: buttonColorForeground),
        label: Text(locales.get(alertData.action!.label).toUpperCase()),
        icon: Icon(alertData.action!.icon),
        onPressed: () async {
          try {
            if (hasAction) {
              await alertData.action!.onTap!();
            }
            dismissAlerts(widget: alertData.widget);
            if (context!.mounted) {
              if (hasValidPath) {
                final path = alertData.action!.path!;
                if (alertData.action!.queryParameters != null) {
                  final uri = Uri(path: path);
                  Utils.pushNamedFromQuery(
                    context: context!,
                    uri: uri,
                    queryParameters: alertData.action!.queryParameters!,
                  );
                } else {
                  Navigator.of(context!).pushNamed(path);
                }
              }
            }
          } catch (e) {
            debugPrint(LogColor.error('Action click: $e'));
          }
        },
      ));
    }

    if (showAction && alertData.widget == AlertWidget.snackBar) {
      onColumn.add(Container(
        margin: const EdgeInsets.only(top: 16),
        child: Wrap(
          spacing: 16,
          children: actions,
        ),
      ));
    }
    mainItems.add(Flex(
      direction: Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: onColumn,
    ));
    Widget content = Container(
      padding: EdgeInsets.all(basePadding),
      color: alertData.color,
      child: Flex(
        direction: Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mainItems,
      ),
    );

    /// Show notification
    try {
      if (!context!.mounted) throw 'context is not mounted';
      switch (alertData.widget) {
        case AlertWidget.banner:
          ScaffoldMessenger.of(context!).showMaterialBanner(
            MaterialBanner(
              actions: actions,
              content: content,
              backgroundColor: alertData.color,
              forceActionsBelow: true,
              padding: EdgeInsets.zero,
            ),
          );
          break;
        case AlertWidget.snackBar:
          ScaffoldMessenger.of(context!).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: content,
              duration: Duration(seconds: alertData.duration!),
              backgroundColor: alertData.color,
              padding: EdgeInsets.zero,
              showCloseIcon: !showAction,
              closeIconColor: alertData.textColor,
            ),
          );
          break;
        case AlertWidget.dialog:
          showDialog<void>(
            context: context!,
            builder: (BuildContext context) => Scaffold(
              primary: false,
              backgroundColor: theme.colorScheme.surface.withOpacity(0.3),
              body: AlertDialog(
                scrollable: alertData.scrollable,
                actions: actions,
                content: content,
                backgroundColor: alertData.color,
                contentPadding: EdgeInsets.zero,
                clipBehavior: Clip.hardEdge,
                actionsPadding: const EdgeInsets.all(16),
                buttonPadding: const EdgeInsets.all(16),
              ),
            ),
          );
          break;
      }
    } catch (error) {
      if (kDebugMode) {
        String debugMessagePrint =
            '////////// Alert: ${alertData.type} ///////////';
        debugMessagePrint += '\n${error.toString()}';
        debugMessagePrint += '\n////////////////////////////';
        print(debugMessagePrint);
      }
    }
  }

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
