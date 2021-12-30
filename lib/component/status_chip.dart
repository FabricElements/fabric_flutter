import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';

/// StatusChip is a chip which shows the status of a campaign.
///
/// [status] This is the current status of said campaign.
/// StatusChip(
///   status: "active",
///   locale: "Campaign Active",
/// );
class StatusChip extends StatelessWidget {
  StatusChip({
    Key? key,
    required this.status,
  }) : super(key: key);
  final String? status;

  @override
  Widget build(BuildContext context) {
    AppLocalizations locales = AppLocalizations.of(context)!;
    Color statusColor = Colors.grey.shade800;
    String baseStatus = status ?? "unknown";
    baseStatus = locales.get("label--$status");

    switch (status) {
      case "draft":
        statusColor = Colors.indigo.shade500;
        break;
      case "review":
        statusColor = Colors.amber.shade900;
        break;
      case "approved":
        statusColor = Colors.deepPurple.shade500;
        break;
      case "rejected":
        statusColor = Colors.red.shade500;
        break;
      case "inactive":
        statusColor = Colors.deepOrange.shade500;
        break;
      case "active":
        statusColor = Colors.green.shade600;
        break;
      case "archived":
        statusColor = Colors.grey.shade700;
    }
    return Chip(
      label: Text(
        baseStatus,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          letterSpacing: 1.1,
          color: Colors.white,
        ),
      ),
      backgroundColor: statusColor,
    );
  }
}
