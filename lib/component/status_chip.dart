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
  /// Creates a compact visual summary for a status value.
  const StatusChip({
    super.key,
    required this.status,
    this.icon,
    this.color,
    this.textColor,
    this.width,
  });

  /// Supplies the raw status key used for localization and default styling.
  final String? status;
  /// Overrides the icon derived from [status].
  final IconData? icon;
  /// Overrides the background color derived from [status].
  final Color? color;
  /// Overrides the label color shown on the chip.
  final Color? textColor;
  /// Constrains the label width when the chip must align with surrounding UI.
  final double? width;

  /// Builds a localized [RawChip] that stays visually consistent with the rest
  /// of the status system.
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

    final text = Text(
      baseStatus,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        letterSpacing: 1.1,
        color: textColor ?? Colors.white,
        overflow: TextOverflow.ellipsis,
      ),
    );

    /// Return a Tooltip with a message and a Chip with an icon and label.
    return RawChip(
      tooltip: locales.get('label--status'),
      avatar: Icon(iconData, color: Colors.white),
      label: width != null ? SizedBox(width: width, child: text) : text,
      backgroundColor: statusColor,
      elevation: 1,
      side: BorderSide.none,
    );
  }
}
