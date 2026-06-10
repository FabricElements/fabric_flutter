import 'package:flutter/material.dart';

import '../helper/utils.dart';
import '../serialized/user_data.dart';
import 'smart_image.dart';

/// Displays a circular avatar for a user and, when available, overlays presence.
///
/// The widget prefers rendering the image from [avatar]. When no image is
/// available, it falls back to initials derived from [firstName], [lastName],
/// or [name], and finally to the default person icon. This behavior keeps
/// profile lists, headers, and similar surfaces informative while user data is
/// still loading or only partially available.
///
/// ```dart
/// UserAvatar(
///   avatar: imageUrl,
///   name: 'Jeffery',
/// );
/// ```
class UserAvatar extends StatelessWidget {
  /// Creates a [UserAvatar] that shows a profile image, initials, or a fallback icon.
  ///
  /// Supply [presence] when the surrounding UI needs a compact online-status
  /// indicator. Omitting it keeps the layout focused on the avatar itself.
  const UserAvatar({
    super.key,
    required this.avatar,
    this.name,
    this.firstName,
    this.lastName,
    this.presence,
  });

  /// Provides the avatar image URL used for the circular profile photo.
  ///
  /// When this value is `null`, the widget falls back to initials or the default
  /// person icon so parent widgets do not need to handle missing media.
  final String? avatar;

  /// Supplies a fallback display name for tooltips and generated initials.
  ///
  /// This value is especially useful when the caller has a single combined name
  /// rather than separate [firstName] and [lastName] values.
  final String? name;

  /// Supplies the preferred first-name portion used for initials and tooltips.
  ///
  /// The widget favors this value over [name] so generated initials stay
  /// consistent with structured user records when both are available.
  final String? firstName;

  /// Supplies the preferred last-name portion used for initials and tooltips.
  ///
  /// The widget combines this value with [firstName] when generating initials
  /// so family names remain visible in compact avatar-only layouts.
  final String? lastName;

  /// Describes the user's current presence for the status badge overlay.
  ///
  /// When `null`, the widget returns only the avatar content and skips the extra
  /// badge so the layout stays compact in contexts that do not track presence.
  final UserPresence? presence;

  /// Builds the avatar using the active [ThemeData] colors and available user data.
  ///
  /// The [BuildContext] supplies theme colors for the avatar background, icon,
  /// and initials text. The tooltip follows the same fallback order as the
  /// displayed content so the UI remains descriptive even while user data is
  /// still loading or partially missing.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final color = theme.colorScheme.onPrimaryContainer;
    final backgroundColor = theme.colorScheme.primaryContainer;
    String abbreviation = Utils.nameAbbreviation(
      firstName: firstName ?? name,
      lastName: lastName,
    );
    Widget avatarContainer = CircleAvatar(
      backgroundColor: backgroundColor,
      child: Icon(Icons.person, color: color),
    );
    if (avatar != null) {
      avatarContainer = CircleAvatar(
        backgroundColor: backgroundColor,
        child: AspectRatio(
          aspectRatio: 1 / 1,
          child: ClipOval(
            child: SmartImage(url: avatar, format: AvailableOutputFormats.png),
          ),
        ),
      );
    } else if (abbreviation.isNotEmpty) {
      avatarContainer = CircleAvatar(
        backgroundColor: backgroundColor,
        child: Text(
          abbreviation,
          style: textTheme.titleMedium?.copyWith(color: color),
        ),
      );
    }

    if (presence == null) {
      return Tooltip(
        message: firstName ?? lastName ?? name ?? abbreviation,
        child: avatarContainer,
      );
    }

    Color statusColor = Colors.transparent;
    switch (presence) {
      case UserPresence.active:
        statusColor = Colors.green;
        break;
      case UserPresence.inactive:
        statusColor = Colors.deepOrange;
        break;
      case UserPresence.away:
        statusColor = Colors.transparent;
        break;
      default:
    }
    final presenceWidget = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
    );
    return AspectRatio(
      aspectRatio: 1 / 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Tooltip(
            message: firstName ?? lastName ?? name ?? abbreviation,
            child: avatarContainer,
          ),
          Positioned(right: 0, top: 0, child: presenceWidget),
        ],
      ),
    );
  }
}
