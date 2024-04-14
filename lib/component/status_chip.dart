import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/utils.dart';

/// StatusChip is a chip which shows the status of a campaign.
///
/// [status] This is the current status of said campaign.
/// StatusChip(
///   status: 'active',
///   locale: 'Active',
/// );
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.icon,
    this.color,
    this.textColor,
  });

  final String? status;
  final IconData? icon;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    String baseStatus = status ?? 'unknown';
    baseStatus = locales.get('label--$status');
    Color statusColor = Utils.statusColor(status);
    IconData iconData = Utils.statusIcon(status);

    /// Override iconData if icon is not null
    iconData = icon ?? iconData;

    /// Override statusColor if color is not null
    statusColor = color ?? statusColor;

    /// Return a Tooltip with a message and a Chip with an icon and label.
    return Tooltip(
      message: locales.get('label--status'),
      child: Chip(
        avatar: Icon(iconData, color: Colors.white),
        label: Text(
          baseStatus,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 1.1,
            color: textColor ?? Colors.white,
          ),
        ),
        backgroundColor: statusColor,
      ),
    );
  }
}
