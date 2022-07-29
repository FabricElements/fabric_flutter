library fabric_flutter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../component/smart_image.dart';
import '../helper/app_localizations_delegate.dart';
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
  Brightness? brightness;
  Widget? child;

  /// Clear all other alerts of the same type
  /// Not recommended for AlertWidget.dialog because it uses Navigator.pop(context!)
  /// and it can affect the navigation
  bool clear;

  AlertData({
    this.action,
    this.dismiss,
    this.title,
    this.body,
    this.duration,
    this.type = AlertType.basic,
    this.widget = AlertWidget.snackBar,
    this.typeString,
    this.image,
    this.color,
    this.titleStyle,
    this.bodyStyle,
    this.clear = false,
    this.brightness,
    this.child,
  });
}

class StateAlert extends ChangeNotifier {
  StateAlert();

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

  /// Display Alert with [show] function
  Future<void> show(AlertData alertData) async {
    assert(context != null, 'context can\'t be null');

    final queryData = MediaQuery.of(context!);
    double width = queryData.size.width;
    double basePadding = 16.0;
    double contentWidth = width - (basePadding * 4);

    // int height = constraints.maxHeight.floor();
    final locales = AppLocalizations.of(context!)!;
    final theme = Theme.of(context!);
    final textTheme = theme.textTheme;
    final brightness = theme.brightness;
    // await Future.delayed(Duration(microseconds: 200));
    if (alertData.typeString != null) {
      alertData.type = typeFromString(alertData.typeString);
    }
    if (kDebugMode) {
      print('////////// Alert: ${alertData.type} ///////////');
      print(alertData.title ?? alertData.body ?? 'UNKNOWN');
      print('////////////////////////////');
    }
    alertData.brightness ??= brightness; // Default
    alertData.brightness ??= Brightness.light;
    // if (alertData.color != null) {
    //   double luminance = alertData.color!.computeLuminance();
    //   alertData.brightness =
    //       luminance > 0.5 ? Brightness.light : Brightness.dark;
    //   // print('------------------ LUMINANCE:::: $luminance -------------');
    // }
    // print(
    //     '------------------ brightness:::: ${alertData.brightness} -------------');
    // alertData.color ??= alertData.brightness == Brightness.light
    //     ? Colors.red.shade200
    //     : Colors.red;
    switch (alertData.type) {
      case AlertType.critical:
        alertData.color ??= Colors.red;
        alertData.duration ??= 600;
        break;
      case AlertType.warning:
        alertData.color ??= Colors.deepOrange;
        alertData.duration ??= 15;
        break;
      case AlertType.success:
        alertData.color ??= Colors.green;
        alertData.duration ??= 5;
        break;
      default:
    }

    /// Set default values for null safety
    alertData.duration ??= 10;
    // alertData.color ??= Colors.grey.shade800;
    alertData.color ??= theme.colorScheme.primary;
    // alertData.titleStyle ??= textTheme.headline5?.apply(color: Colors.white);
    alertData.titleStyle ??= textTheme.headline5;
    // alertData.bodyStyle ??= textTheme.bodyText1?.apply(color: Colors.grey.shade50);
    alertData.bodyStyle ??= textTheme.bodyText1;

    alertData.titleStyle = alertData.titleStyle!.apply(
      color: alertData.brightness == Brightness.light
          ? Colors.grey.shade900
          : Colors.white,
    );
    alertData.bodyStyle = alertData.bodyStyle!.apply(
      color: alertData.brightness == Brightness.light
          ? Colors.grey.shade800
          : Colors.grey.shade50,
    );

    /// Set global colors
    Color backgroundColor = alertData.brightness == Brightness.light
        ? Colors.white
        : alertData.color!;
    Color buttonColor = alertData.brightness == Brightness.light
        ? alertData.color!
        : Colors.white;
    Color buttonColorText = alertData.brightness == Brightness.light
        ? Colors.white
        : alertData.color!;
    Color dismissButtonColor = alertData.brightness == Brightness.light
        ? theme.textTheme.button?.color ?? Colors.grey.shade800
        : Colors.white;

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

    try {
      List<Widget> onColumn = [];
      List<Widget> mainItems = [];

      /// Title
      if (alertData.title != null) {
        onColumn.add(Container(
          constraints: BoxConstraints(minWidth: 50, maxWidth: contentWidth),
          margin: const EdgeInsets.only(bottom: 8),
          child: Text(
            alertData.title!,
            style: alertData.titleStyle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ));
      }
      if (alertData.body != null) {
        onColumn.add(Container(
          constraints: BoxConstraints(minWidth: 50, maxWidth: contentWidth),
          margin: const EdgeInsets.only(bottom: 8),
          child: Text(
            alertData.body!,
            style: alertData.bodyStyle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
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
            child: SmartImage(url: alertData.image!),
          ),
        ));
      }

      /// Add child widget before actions
      if (alertData.child != null) {
        onColumn.add(Container(
          margin: const EdgeInsets.only(bottom: 16, top: 16),
          constraints: BoxConstraints(
            minHeight: 50,
            maxHeight: 400,
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
      bool hasDismissAction = alertData.dismiss!.onTap != null;
      if (hasAction || hasValidPath) {
        actions.add(ElevatedButton.icon(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(buttonColor),
            foregroundColor: MaterialStateProperty.all(buttonColorText),
          ),
          label: Text(locales.get(alertData.action!.label).toUpperCase()),
          icon: Icon(alertData.action!.icon),
          onPressed: () async {
            try {
              if (hasAction) {
                await alertData.action!.onTap!();
              }
              dismissAlerts(widget: alertData.widget);
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
            } catch (e) {
              if (kDebugMode) print('Action click: $e');
            }
          },
        ));
      }

      actions.add(TextButton.icon(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all(dismissButtonColor),
        ),
        icon: Icon(alertData.dismiss!.icon!),
        label: Text(locales.get(alertData.dismiss!.label).toUpperCase()),
        onPressed: () async {
          try {
            if (hasDismissAction) {
              await alertData.dismiss!.onTap!();
            }
            dismissAlerts(widget: alertData.widget);
          } catch (e) {
            if (kDebugMode) print('Dismiss click: $e');
          }
        },
      ));

      if (hasAction && alertData.widget == AlertWidget.snackBar) {
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
        color: Colors.white,
        child: Container(
          padding: EdgeInsets.all(basePadding),
          color: backgroundColor,
          child: Flex(
            direction: Axis.vertical,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: mainItems,
          ),
        ),
      );
      switch (alertData.widget) {
        case AlertWidget.banner:
          ScaffoldMessenger.of(context!).showMaterialBanner(
            MaterialBanner(
              actions: actions,
              content: content,
              backgroundColor: backgroundColor,
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
              backgroundColor: backgroundColor,
              padding: EdgeInsets.zero,
            ),
          );
          break;
        case AlertWidget.dialog:
          showDialog<void>(
            context: context!,
            builder: (BuildContext context) => AlertDialog(
              scrollable: true,
              actions: actions,
              content: content,
              backgroundColor: backgroundColor,
              contentPadding: EdgeInsets.zero,
              clipBehavior: Clip.hardEdge,
              buttonPadding: const EdgeInsets.all(16),
            ),
          );
          break;
      }
    } catch (error) {
      if (kDebugMode) {
        print('/////////////////////');
        print(error);
        print('/////////////////////');
      }
    }
  }
}
