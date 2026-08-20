import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../helper/app_global.dart';
import '../helper/app_localizations_delegate.dart';
import '../helper/log_color.dart';
import '../helper/options.dart';
import '../helper/utils.dart';
import 'content_container.dart';
import 'smart_image.dart';

/// Identifies the semantic tone of an alert so shared presentation code can
/// choose appropriate colors, defaults, and logging behavior.
enum AlertType {
  /// Presents a basic informational alert with neutral styling.
  basic,

  /// Presents a critical alert for errors requiring immediate action.
  critical,

  /// Presents a success confirmation alert with positive styling.
  success,

  /// Presents a warning alert for cautionary messages.
  warning,
}

/// Selects which Material surface is used to present an alert.
enum AlertWidget {
  /// Shows the alert inside a transient [SnackBar].
  snackBar,

  /// Shows the alert inside a persistent [MaterialBanner].
  banner,

  /// Shows the alert inside an [AlertDialog].
  dialog,
}

/// Converts a stored string value back into an [AlertType].
///
/// Unknown or missing values intentionally fall back to [AlertType.basic] so
/// callers can safely deserialize historic or partially populated data.
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

/// Resolves the [BuildContext] used to present or dismiss an alert.
///
/// A caller-supplied [context] is preferred, but only while it is still
/// mounted; otherwise the root context behind [AppGlobal.navigatorKey] is used.
/// Returns `null` when neither is usable, which lets callers degrade to a debug
/// log instead of throwing.
///
/// This is what makes the `context` argument optional in [alertData] and
/// [dismissAlerts]: after an `await` a caller can simply omit it and let the
/// root context be resolved here, which satisfies
/// `use_build_context_synchronously` correctly rather than suppressing it.
///
/// Exposed publicly so sibling helpers that genuinely need a live context —
/// for example to perform an [InheritedWidget] lookup such as
/// `AppLocalizations.of(context)` — can reuse the exact same fallback instead of
/// silently dropping their work when the caller's element is gone.
BuildContext? alertContext(BuildContext? context) {
  if (context != null && context.mounted) return context;
  final fallback = AppGlobal.navigatorKey.currentContext;
  if (fallback != null && fallback.mounted) return fallback;
  return null;
}

/// Dismisses the current alert presentation for the given [widget].
///
/// When `dismissAll` is `true`, every visible alert of the same widget type is
/// cleared. The [context] is optional: when omitted, stale, or unmounted, the
/// root context behind [AppGlobal.navigatorKey] is used instead, so this is safe
/// to call after an `await` without a `mounted` guard.
void dismissAlerts({
  bool dismissAll = false,
  required AlertWidget widget,
  BuildContext? context,
}) {
  final safeContext = alertContext(context);
  // Check if the widget is still 'alive' before using the context
  if (safeContext == null) {
    debugPrint(
      'Dismiss alert skipped: no mounted context and no AppGlobal.navigatorKey.',
    );
    return;
  }
  switch (widget) {
    case AlertWidget.banner:
      if (dismissAll) {
        ScaffoldMessenger.of(safeContext).clearMaterialBanners();
      } else {
        ScaffoldMessenger.of(safeContext).removeCurrentMaterialBanner();
      }
      break;
    case AlertWidget.snackBar:
      if (dismissAll) {
        ScaffoldMessenger.of(safeContext).clearSnackBars();
      } else {
        ScaffoldMessenger.of(safeContext).removeCurrentSnackBar();
      }
      break;
    case AlertWidget.dialog:
      bool isOpen = isDialogOpen(safeContext);
      if (isOpen) Navigator.of(safeContext).pop();
      break;
  }
}

/// Returns whether a popup-style route is currently visible for `context`.
///
/// This is used before dismissing dialog alerts so the navigator is only popped
/// when a matching overlay is actually present.
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

/// Shows a configured alert using a [SnackBar], [MaterialBanner], or dialog.
///
/// The helper centralizes alert theming, localized button labels, default
/// durations, and safe dismissal logic so feature widgets can focus on domain
/// behavior instead of repeating presentation code. Use [title], [body],
/// [child], [image], and [icon] to shape the content; use [action] and
/// [dismiss] to customize button behavior; and choose [widget], [type],
/// [scrollable], and [barrierDismissible] to match the surrounding UX.
///
/// ## Calling this after an `await`
///
/// [context] is optional. **After an `await`, prefer omitting it entirely:**
///
/// ```dart
/// await save();
/// alertData(body: 'Saved', type: AlertType.success);
/// ```
///
/// This is not merely a lint workaround — it is the safer call. The helper has
/// always guarded against unmounted contexts internally, but
/// `use_build_context_synchronously` fires on *referencing* a [BuildContext]
/// after an async gap and cannot see that the callee is safe, so passing a
/// context post-`await` forces callers into pointless `mounted` guards, `//
/// ignore:` comments, or disabling the lint outright. Not passing one removes
/// the reference, so the lint is satisfied correctly and real violations
/// elsewhere stay visible. Keep passing [context] for synchronous calls, where
/// the local subtree context is the most accurate presenter.
///
/// ## Wiring required for the contextless path
///
/// Resolution goes through [alertContext], which falls back to
/// [AppGlobal.navigatorKey]. Consumers **must** wire the global keys for the
/// contextless path to render UI:
///
/// ```dart
/// MaterialApp(
///   navigatorKey: AppGlobal.navigatorKey,
///   scaffoldMessengerKey: AppGlobal.snackbarKey,
///   // ...
/// );
/// ```
///
/// Without that wiring — or before the first frame — no context is available
/// and the alert degrades gracefully to a `debugPrint` and returns; it never
/// throws.
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

  /// Customizes the primary action button and optional navigation behavior.
  ButtonOptions? action,

  /// Customizes the dismiss button shown for every alert surface.
  ButtonOptions? dismiss,

  /// Overrides the container color chosen from [type].
  Color? color,

  /// Overrides the text style applied to [title].
  TextStyle? titleStyle,

  /// Overrides the text style applied to [body].
  TextStyle? bodyStyle,

  /// Overrides the foreground color used by text and icons.
  Color? textColor,

  /// Inserts additional custom content before the alert actions.
  Widget? child,

  /// Clear all other alerts of the same type
  bool clear = true,

  /// Scrollable content for [AlertWidget.dialog] using [AlertDialog]
  bool scrollable = false,

  /// Requests a fullscreen dialog presentation when supported.
  bool fullscreenDialog = false,

  /// Controls whether tapping outside a dialog dismisses it.
  bool barrierDismissible = true,

  /// Displays a leading status icon above the main content.
  IconData? icon,

  /// Supplies the active [BuildContext] used to locate overlay presenters.
  ///
  /// Optional. When omitted — or when the supplied context has since been
  /// unmounted — the root context behind [AppGlobal.navigatorKey] is used
  /// instead. **After an `await`, prefer calling `alertData(...)` without a
  /// `context` argument**: the call is equally safe and avoids a spurious
  /// `use_build_context_synchronously` diagnostic at the call site.
  BuildContext? context,
}) async {
  if (typeString != null) {
    type = typeFromString(typeString);
  }
  // Prefer the caller's context while it is still usable, otherwise fall back
  // to the app root so post-await callers can omit it entirely.
  final ctx = alertContext(context);
  if (kDebugMode || ctx == null) {
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
  if (ctx == null) {
    debugPrint(
      LogColor.warning(
        'Alert context is unavailable, so the alert was only logged. Pass a '
        'mounted context, or assign AppGlobal.navigatorKey to '
        'MaterialApp.navigatorKey so alerts can resolve the root context.',
      ),
    );
    return;
  }

  final queryData = MediaQuery.of(ctx);
  double width = queryData.size.width;
  double basePadding = 16;
  double contentWidth = width - (basePadding * 4);
  final locales = AppLocalizations.of(ctx);
  final theme = Theme.of(ctx);
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

  /// Screen reader users need more time to read an alert than the fixed
  /// snackbar duration allows, so critical/warning snackbars stay open longer
  /// when accessible navigation (e.g. TalkBack/VoiceOver) is active instead of
  /// auto-dismissing while assistive technology is still reading the message.
  final bool accessibleNavigation = MediaQuery.accessibleNavigationOf(ctx);
  if (accessibleNavigation &&
      widget == AlertWidget.snackBar &&
      (type == AlertType.critical || type == AlertType.warning)) {
    duration = duration < 60 ? 60 : duration;
  }

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
    dismissAlerts(dismissAll: true, widget: widget, context: ctx);
  }

  List<Widget> onColumn = [];
  List<Widget> mainItems = [];

  /// Title
  if (title != null) {
    onColumn.add(
      Container(
        constraints: BoxConstraints(minWidth: 50, maxWidth: contentWidth),
        child: Semantics(
          button: true,
          label: title,
          hint: locales.get('label--copy-to-clipboard'),
          child: InkWell(
            onTap: () {
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
      ),
    );
  }
  if (body != null) {
    onColumn.add(
      Container(
        constraints: BoxConstraints(minWidth: 50, maxWidth: contentWidth),
        child: Semantics(
          button: true,
          label: body,
          hint: locales.get('label--copy-to-clipboard'),
          child: InkWell(
            onTap: () {
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
            // Purely decorative: the title/body text already conveys the
            // alert's meaning, so this icon is excluded from semantics to
            // avoid a redundant announcement.
            child: ExcludeSemantics(
              child: CircleAvatar(
                backgroundColor: buttonColor,
                child: Icon(icon, color: buttonColorForeground),
              ),
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
          child: SmartImage(
            key: ValueKey('alert-image-$image'),
            url: image,
            format: AvailableOutputFormats.jpeg,
          ),
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
          maxHeight: scrollable ? double.infinity : 900,
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
            dismissAlerts(widget: widget);
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
              // `ctx` may be gone by the time the action resolves; fall back to
              // the root context through [alertContext]. The explicit
              // `ctx.mounted` check is what satisfies
              // `use_build_context_synchronously` here, since navigation below
              // genuinely needs a live context.
              final safeContext = ctx.mounted ? ctx : alertContext(null);
              if (safeContext == null || !safeContext.mounted) return;
              dismissAlerts(widget: widget, context: safeContext);
              if (hasValidPath) {
                final path = action!.path!;
                if (action.queryParameters != null) {
                  final uri = Uri(path: path);
                  Utils.pushNamedFromQuery(
                    context: safeContext,
                    uri: uri,
                    queryParameters: action.queryParameters!,
                  );
                } else {
                  Navigator.of(safeContext).pushNamed(path);
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

  /// Announce the alert to assistive technology as it appears. This is only
  /// triggered once per [alertData] call (a real state transition), not on
  /// every rebuild, so it stays non-spammy.
  final String announcement = [
    title,
    body,
  ].where((value) => value != null && value.isNotEmpty).join('. ');
  if (announcement.isNotEmpty) {
    SemanticsService.sendAnnouncement(
      View.of(ctx),
      announcement,
      Directionality.of(ctx),
    );
  }
  if (widget == AlertWidget.banner) {
    // A [MaterialBanner] persists on screen and can be replaced in place, so
    // mark it as a live region for assistive technology that supports it.
    content = Semantics(container: true, liveRegion: true, child: content);
  }

  /// Show notification
  try {
    switch (widget) {
      case AlertWidget.banner:
        ScaffoldMessenger.of(ctx).showMaterialBanner(
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
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: content,
            duration: Duration(seconds: duration),
            backgroundColor: color,
            padding: EdgeInsets.zero,
            showCloseIcon: false,
            closeIconColor: textColor,
            width: kIsWeb ? 900 : null,
            margin: kIsWeb ? null : EdgeInsets.all(16),
          ),
        );
        break;
      case AlertWidget.dialog:
        showDialog<void>(
          context: ctx,
          fullscreenDialog: fullscreenDialog,
          barrierDismissible: barrierDismissible,
          builder: (BuildContext context) => Scaffold(
            primary: false,
            backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.3),
            body: ContentContainer(
              child: PointerInterceptor(
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
          ),
        );
        break;
    }
  } catch (error) {
    String debugMessagePrint = error.toString();
    debugPrint(LogColor.error(debugMessagePrint));
  }
}
