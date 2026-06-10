import 'dart:async';

import 'package:flutter/material.dart';
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
          open = true;
          lastConnected = connected;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mounted && open) {
            await Future.delayed(const Duration(seconds: 10));
            setState(() {
              open = false;
            });
          }
        });
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
            child: Container(
              // height: kToolbarHeight,
              margin: EdgeInsets.all(35),
              padding: EdgeInsets.fromLTRB(16, 4, 4, 4),
              constraints: BoxConstraints(
                maxWidth: 300,
                minWidth: 200,
                maxHeight: kToolbarHeight,
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
                  Icon(icon, color: iconColor, size: 24),
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
        );
      },
    );
  }
}
