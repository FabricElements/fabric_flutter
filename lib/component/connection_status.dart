import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../state/state_global.dart';

class ConnectionStatus extends StatefulWidget {
  const ConnectionStatus({super.key});

  @override
  State<ConnectionStatus> createState() => _ConnectionStatusState();
}

class _ConnectionStatusState extends State<ConnectionStatus> {
  bool open = false;
  bool lastConnected = true;

  @override
  Widget build(BuildContext context) {
    final stateGlobal = Provider.of<StateGlobal>(context, listen: false);
    final locales = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    // Use system theme colors
    final brightness = MediaQuery.of(context).platformBrightness;
    if (brightness == Brightness.dark) {
      theme.copyWith(colorScheme: ThemeData.dark().colorScheme);
    } else {
      theme.copyWith(colorScheme: ThemeData.light().colorScheme);
    }
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
