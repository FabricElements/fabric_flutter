import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/log_color.dart';
import '../helper/options.dart';
import '../helper/utils.dart';
import 'content_container.dart';
import 'smart_image.dart';

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
enum AlertWidget { snackBar, banner, dialog }

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
  required BuildContext context,
}) {
  // Check if the widget is still 'alive' before using the context
  if (!context.mounted) {
    debugPrint('Dismiss alert context is not mounted');
    return;
  }
  switch (widget) {
    case AlertWidget.banner:
      if (dismissAll) {
        ScaffoldMessenger.of(context).clearMaterialBanners();
      } else {
        ScaffoldMessenger.of(context).removeCurrentMaterialBanner();
      }
      break;
    case AlertWidget.snackBar:
      if (dismissAll) {
        ScaffoldMessenger.of(context).clearSnackBars();
      } else {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
      }
      break;
    case AlertWidget.dialog:
      bool isOpen = isDialogOpen(context);
      if (isOpen) Navigator.of(context).pop();
      break;
  }
}

/// Check if a dialog is open
bool isDialogOpen(BuildContext context) {
  bool isDialog = false;
  Navigator.popUntil(context, (route) {
    if (route is PopupRoute) {
      isDialog = true;
    }
    return true; // Return true immediately so we don't actually pop anything
  });
  return isDialog;
}

/// Alert Data Object
void alertData<T>({
  /// Notification title
  final String? title,

  /// Notification body
  final String? body,

  /// Alert duration in seconds
  int? duration,

  /// type used for the Alert
  AlertType type = AlertType.basic,

  /// AlertWidget changes the type of widget used for the alert
  final AlertWidget widget = AlertWidget.snackBar,

  /// typeString used to return [AlertType]
  final String? typeString,

  /// Image URL
  final String? image,

  ButtonOptions? action,
  ButtonOptions? dismiss,
  Color? color,
  TextStyle? titleStyle,
  TextStyle? bodyStyle,
  Color? textColor,
  Widget? child,

  /// Clear all other alerts of the same type
  /// Not recommended for AlertWidget.dialog because it uses Navigator.pop(context!)
  /// and it can affect the navigation
  bool clear = false,

  /// Scrollable content for [AlertWidget.dialog] using [AlertDialog]
  bool scrollable = false,
  IconData? icon,
  required BuildContext context,
}) async {
  if (typeString != null) {
    type = typeFromString(typeString);
  }
  if (kDebugMode) {
    String debugMessagePrint = '................................';
    if (title != null) debugMessagePrint += '\n$title';
    if (body != null) debugMessagePrint += '\n$body';
    debugMessagePrint += '\n................................';
    switch (type) {
      case AlertType.critical:
        debugPrint(LogColor.error(debugMessagePrint));
        break;
      case AlertType.warning:
        debugPrint(LogColor.warning(debugMessagePrint));
        break;
      case AlertType.success:
        debugPrint(LogColor.success(debugMessagePrint));
        break;
      default:
        debugPrint(LogColor.info(debugMessagePrint));
    }
  }

  // Check if the widget is still 'alive' before using the context
  if (!context.mounted) {
    debugPrint('Alert context is not mounted');
    return;
  }

  final queryData = MediaQuery.of(context);
  double width = queryData.size.width;
  double basePadding = 16;
  double contentWidth = width - (basePadding * 4);
  final locales = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final textTheme = theme.textTheme;

  Color buttonColor = theme.colorScheme.primary;
  Color buttonColorForeground = theme.colorScheme.onPrimary;
  switch (type) {
    case AlertType.critical:
      color = theme.colorScheme.errorContainer;
      textColor = theme.colorScheme.onErrorContainer;
      duration ??= 15;
      buttonColor = theme.colorScheme.error;
      buttonColorForeground = theme.colorScheme.onError;
      break;
    case AlertType.warning:
      color = theme.colorScheme.surface;
      textColor = theme.colorScheme.onSurface;
      duration ??= 15;
      buttonColor = theme.colorScheme.error;
      buttonColorForeground = theme.colorScheme.onError;
      break;
    case AlertType.success:
      color = theme.colorScheme.primaryContainer;
      textColor = theme.colorScheme.onPrimaryContainer;
      duration ??= 5;
      buttonColor = theme.colorScheme.primary;
      buttonColorForeground = theme.colorScheme.onPrimary;
      break;
    default:
  }

  /// Set default values for null safety
  duration ??= 4;
  color ??= theme.colorScheme.surfaceContainerHighest;
  textColor ??= theme.colorScheme.onSurfaceVariant;
  titleStyle ??= textTheme.titleLarge;
  bodyStyle ??= textTheme.bodyLarge;

  titleStyle = titleStyle?.apply(color: textColor);
  bodyStyle = bodyStyle?.apply(color: textColor);

  /// Dismiss
  dismiss ??= ButtonOptions();
  dismiss.icon ??= Icons.close;
  if (dismiss.label.isEmpty) {
    dismiss.label = 'label--dismiss';
  }

  /// Action
  action ??= ButtonOptions();
  action.icon ??= Icons.navigate_next;
  if (action.label.isEmpty) {
    action.label = 'label--continue';
  }

  /// Hide all alerts from same type to prevent overlap
  if (clear) {
    dismissAlerts(dismissAll: true, widget: widget, context: context);
  }

  List<Widget> onColumn = [];
  List<Widget> mainItems = [];

  /// Title
  if (title != null) {
    onColumn.add(
      Container(
        constraints: BoxConstraints(minWidth: 50, maxWidth: contentWidth),
        child: RawMaterialButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: title));
          },
          child: Text(
            title,
            style: titleStyle,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
      ),
    );
  }
  if (body != null) {
    onColumn.add(
      Container(
        constraints: BoxConstraints(minWidth: 50, maxWidth: contentWidth),
        child: RawMaterialButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: body));
          },
          child: Text(
            body,
            style: bodyStyle,
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
      ),
    );
  }

  /// Image
  if (icon != null) {
    mainItems.add(
      Container(
        width: double.maxFinite,
        height: 48,
        color: color,
        child: Align(
          alignment: Alignment.centerLeft,
          child: AspectRatio(
            aspectRatio: 1 / 1,
            child: CircleAvatar(
              backgroundColor: buttonColor,
              child: Icon(icon, color: buttonColorForeground),
            ),
          ),
        ),
      ),
    );
  }

  /// Image
  if (image != null) {
    mainItems.add(
      Container(
        width: double.maxFinite,
        height: 200,
        constraints: const BoxConstraints(
          minHeight: 50,
          minWidth: 50,
          maxHeight: 300,
          maxWidth: double.maxFinite,
        ),
        color: color,
        child: AspectRatio(
          aspectRatio: 3 / 1,
          child: SmartImage(url: image, format: AvailableOutputFormats.jpeg),
        ),
      ),
    );
  }

  /// Add child widget before actions
  if (child != null) {
    onColumn.add(
      Container(
        constraints: BoxConstraints(
          minHeight: 50,
          maxHeight: 900,
          maxWidth: contentWidth,
        ),
        child: child,
      ),
    );
  }

  /// Actions
  List<Widget> actions = [];
  bool hasValidPath = action.path != null && action.path!.isNotEmpty;
  bool hasAction = action.onTap != null;
  bool showAction = hasAction || hasValidPath;
  bool hasDismissAction = dismiss.onTap != null;
  actions.add(
    PointerInterceptor(
      child: TextButton.icon(
        style: TextButton.styleFrom(
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          iconColor: theme.colorScheme.onSurface,
        ),
        icon: Icon(dismiss.icon!),
        label: Text(locales.get(dismiss.label).toUpperCase()),
        onPressed: () async {
          try {
            dismissAlerts(widget: widget, context: context);
            if (hasDismissAction) {
              await dismiss!.onTap!();
            }
          } catch (e) {
            debugPrint(LogColor.error('Dismiss click: $e'));
          }
        },
      ),
    ),
  );
  if (showAction) {
    actions.add(
      PointerInterceptor(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            iconColor: buttonColorForeground,
            backgroundColor: buttonColor,
            foregroundColor: buttonColorForeground,
          ),
          label: Text(locales.get(action.label).toUpperCase()),
          icon: Icon(action.icon),
          onPressed: () async {
            try {
              if (hasAction) {
                await action!.onTap!();
              }
              dismissAlerts(widget: widget, context: context);
              if (hasValidPath) {
                final path = action!.path!;
                if (action.queryParameters != null) {
                  final uri = Uri(path: path);
                  Utils.pushNamedFromQuery(
                    context: context,
                    uri: uri,
                    queryParameters: action.queryParameters!,
                  );
                } else {
                  Navigator.of(context).pushNamed(path);
                }
              }
            } catch (e) {
              debugPrint(LogColor.error('Action click: $e'));
            }
          },
        ),
      ),
    );
  }

  if (actions.isNotEmpty && widget == AlertWidget.snackBar) {
    onColumn.add(Wrap(spacing: 16, runSpacing: 16, children: actions));
  }
  mainItems.add(
    Flex(
      direction: Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: onColumn,
    ),
  );
  Widget content = Container(
    padding: EdgeInsets.all(basePadding),
    color: color,
    child: PointerInterceptor(
      child: SizedBox(
        width: double.maxFinite,
        child: Flex(
          direction: Axis.vertical,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: mainItems,
        ),
      ),
    ),
  );

  /// Show notification
  try {
    switch (widget) {
      case AlertWidget.banner:
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            actions: actions,
            content: content,
            backgroundColor: color,
            forceActionsBelow: true,
            padding: EdgeInsets.zero,
          ),
        );
        break;
      case AlertWidget.snackBar:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: content,
            duration: Duration(seconds: duration),
            backgroundColor: color,
            padding: EdgeInsets.zero,
            showCloseIcon: false,
            closeIconColor: textColor,
            width: 900,
          ),
        );
        break;
      case AlertWidget.dialog:
        showDialog<void>(
          context: context,
          builder: (BuildContext context) => Scaffold(
            primary: false,
            backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.3),
            body: ContentContainer(
              child: AlertDialog(
                scrollable: scrollable,
                actions: actions,
                content: content,
                backgroundColor: color,
                contentPadding: EdgeInsets.zero,
                clipBehavior: Clip.hardEdge,
                actionsPadding: const EdgeInsets.all(16),
                buttonPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        );
        break;
    }
  } catch (error) {
    String debugMessagePrint = error.toString();
    debugPrint(LogColor.error(debugMessagePrint));
  }
}
