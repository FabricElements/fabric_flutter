import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';

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
    Color statusColor = Colors.grey.shade800;
    String baseStatus = status ?? 'unknown';
    baseStatus = locales.get('label--$status');
    IconData iconData = Icons.circle;

    switch (status) {
      case 'draft':
        statusColor = Colors.blueGrey.shade600;
        iconData = Icons.circle;
        break;
      case 'review':
        statusColor = Colors.amber.shade900;
        iconData = Icons.remove_red_eye;
        break;
      case 'approved':
        statusColor = Colors.deepPurple.shade500;
        iconData = Icons.check_circle;
        break;
      case 'rejected':
        iconData = Icons.warning;
        statusColor = Colors.red.shade500;
        break;
      case 'inactive':
        iconData = Icons.stop_circle;
        statusColor = Colors.amber.shade500;
        break;
      case 'paused':
        iconData = Icons.pause_circle;
        statusColor = Colors.deepOrange.shade500;
        break;
      case 'scheduled':
        iconData = Icons.schedule;
        statusColor = Colors.deepPurple.shade500;
        break;
      case 'active':
        iconData = Icons.incomplete_circle;
        statusColor = Colors.teal.shade600;
        break;
      case 'archived':
        iconData = Icons.archive;
        statusColor = Colors.grey.shade700;
        break;
      case 'suspended':
        iconData = Icons.warning;
        statusColor = Colors.red.shade500;
        break;
    }

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
