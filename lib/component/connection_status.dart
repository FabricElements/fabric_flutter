import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../state/state_global.dart';

/// Shows a transient banner when network connectivity changes.
///
/// The widget listens to [StateGlobal.streamConnection] and briefly surfaces the
/// latest online or offline state so users understand why network-backed actions
/// may succeed, fail, or recover.
class ConnectionStatus extends StatefulWidget {
  /// Creates the connectivity banner widget.
  ///
  /// The optional [key] lets ancestor widgets preserve this [StatefulWidget]
  /// when the surrounding tree rebuilds.
  const ConnectionStatus({super.key});

  /// Creates the mutable state that tracks banner visibility across updates.
  ///
  /// The returned [_ConnectionStatusState] keeps the latest connectivity value
  /// so the banner only opens when the status actually changes.
  @override
  State<ConnectionStatus> createState() => _ConnectionStatusState();
}

/// Tracks the last known connection state and auto-hides the status banner.
///
/// The state keeps enough local information to detect connectivity changes,
/// show the status message, and dismiss it automatically after a short delay.
class _ConnectionStatusState extends State<ConnectionStatus> {
  /// Stores whether the banner is currently visible.
  ///
  /// The value becomes `true` when a new connectivity state arrives and returns
  /// to `false` after the banner is dismissed automatically or manually.
  bool open = false;

  /// Stores the last connectivity value emitted by [StateGlobal.streamConnection].
  ///
  /// The cached value prevents duplicate stream emissions from reopening the
  /// banner when the connection status has not actually changed.
  bool lastConnected = true;

  /// Holds the pending auto-dismiss timer for the visible banner.
  ///
  /// Only one dismissal may be in flight at a time. The timer is replaced when a
  /// new connectivity change reopens the banner and cancelled in [dispose] so it
  /// can never call [setState] on an unmounted state.
  Timer? _dismissTimer;

  /// How long the banner remains visible before dismissing itself.
  static const Duration _autoDismissDelay = Duration(seconds: 10);

  /// Opens the banner and schedules its automatic dismissal.
  ///
  /// Scheduling happens outside the build phase so a rebuild never stacks
  /// additional pending dismissals on top of the previous ones.
  void _openBanner() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_autoDismissDelay, () {
      if (!mounted) return;
      setState(() {
        open = false;
      });
    });
  }

  /// Cancels any pending dismissal before the state leaves the tree.
  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  /// Builds the connectivity banner for the current [BuildContext].
  ///
  /// The returned [Widget] listens to [StateGlobal.streamConnection], updates
  /// the local visibility state when the connection changes, and schedules an
  /// automatic dismissal so the notification does not remain on screen
  /// indefinitely.
  @override
  Widget build(BuildContext context) {
    final stateGlobal = Provider.of<StateGlobal>(context, listen: false);
    final locales = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return StreamBuilder(
      stream: stateGlobal.streamConnection,
      builder: (context, snapshot) {
        final connected = snapshot.data ?? stateGlobal.connected;
        if (lastConnected != connected) {
          // Reflected immediately so the banner renders in this same frame; the
          // dismissal is a timer rather than a per-build post-frame callback so
          // unrelated rebuilds cannot stack additional pending dismissals.
          open = true;
          lastConnected = connected;
          _openBanner();
          // Announce the transition (not every rebuild) so screen reader users
          // learn about connectivity changes even while looking elsewhere.
          final announcement = connected
              ? locales.get('notification--you-are-back-online')
              : locales.get('notification--you-are--offline');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              SemanticsService.sendAnnouncement(
                View.of(context),
                announcement,
                Directionality.of(context),
              );
            }
          });
        }
        late IconData icon;
        late String message;
        late Color iconColor;
        if (connected) {
          icon = Icons.wifi;
          message = locales.get('label--online');
          iconColor = theme.colorScheme.primary;
        } else {
          icon = Icons.wifi_off;
          message = locales.get('label--offline');
          iconColor = theme.colorScheme.error;
        }
        if (!open) return SizedBox.shrink();
        return Theme(
          data: theme,
          child: SafeArea(
            child: Semantics(
              // The banner text changes in place (online/offline), so mark it
              // as a live region for assistive technology that supports it.
              container: true,
              liveRegion: true,
              child: Container(
                // height: kToolbarHeight,
                margin: EdgeInsets.all(35),
                padding: EdgeInsets.fromLTRB(16, 4, 4, 4),
                constraints: BoxConstraints(
                  maxWidth: 300,
                  minWidth: 200,
                  // No maxHeight so the banner can grow with a long message, or
                  // with a larger text scale where the host app opted in,
                  // instead of clipping it.
                  minHeight: kToolbarHeight,
                ),
                // width: 200,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 16,
                  children: [
                    Semantics(
                      label: message,
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    Expanded(
                      child: Text(
                        message,
                        style: textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      color: theme.colorScheme.onSurfaceVariant,
                      tooltip: locales.get('label--dismiss'),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            open = false;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
