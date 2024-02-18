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
  });

  final String? status;

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    Color statusColor = Colors.grey.shade800;
    String baseStatus = status ?? 'unknown';
    baseStatus = locales.get('label--$status');
    IconData icon = Icons.circle;

    switch (status) {
      case 'draft':
        statusColor = Colors.blueGrey.shade600;
        icon = Icons.circle;
        break;
      case 'review':
        statusColor = Colors.amber.shade900;
        icon = Icons.remove_red_eye;
        break;
      case 'approved':
        statusColor = Colors.deepPurple.shade500;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        icon = Icons.warning;
        statusColor = Colors.red.shade500;
        break;
      case 'inactive':
        icon = Icons.warning;
        statusColor = Colors.red.shade500;
        break;
      case 'paused':
        icon = Icons.pause_circle;
        statusColor = Colors.deepOrange.shade500;
        break;
      case 'scheduled':
        icon = Icons.schedule;
        statusColor = Colors.deepPurple.shade500;
        break;
      case 'active':
        icon = Icons.incomplete_circle;
        statusColor = Colors.teal.shade600;
        break;
      case 'archived':
        icon = Icons.archive;
        statusColor = Colors.grey.shade700;
        break;
      case 'suspended':
        icon = Icons.warning;
        statusColor = Colors.red.shade500;
        break;
    }
    return Tooltip(
      message: locales.get('label--status'),
      child: Chip(
        avatar: Icon(icon, color: Colors.white),
        label: Text(
          baseStatus,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
        backgroundColor: statusColor,
      ),
    );
  }
}
