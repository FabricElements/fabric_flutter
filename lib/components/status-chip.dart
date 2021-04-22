import 'package:flutter/material.dart';

import '../helpers/locales.dart';

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
    AppLocalizations? locales = AppLocalizations.of(context);
    Color statusColor = Colors.grey.shade800;
    String baseStatus = status ?? "unknown";
    switch (status) {
      case "draft":
        statusColor = Colors.indigo.shade500;
        baseStatus = locales?.get("status-draft") ?? "Draft";
        break;
      case "review":
        statusColor = Colors.amber.shade900;
        baseStatus = locales!.get("status-review") ?? "Review";
        break;
      case "approved":
        statusColor = Colors.deepPurple.shade500;
        baseStatus = locales!.get("status-approved") ?? "Approved";
        break;
      case "rejected":
        statusColor = Colors.red.shade500;
        baseStatus = locales!.get("status-rejected") ?? "Rejected";
        break;
      case "inactive":
        statusColor = Colors.deepOrange.shade500;
        baseStatus = locales!.get("status-inactive") ?? "Inactive";
        break;
      case "active":
        statusColor = Colors.green.shade600;
        baseStatus = locales!.get("status-active") ?? "Active";
        break;
      case "archived":
        statusColor = Colors.grey.shade700;
        baseStatus = locales!.get("status-archived") ?? "Archived";
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
