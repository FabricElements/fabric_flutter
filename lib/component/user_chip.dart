import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../serialized/user_data.dart';
import '../state/state_users.dart';
import 'user_avatar.dart';

/// Builds a chip that displays a user's resolved profile name and avatar.
///
/// The widget reads user metadata from [StateUsers] so callers can provide a
/// user id and receive provider-driven updates for names, avatars, and
/// presence.
class UserChip extends StatefulWidget {
  /// Creates a widget that resolves user metadata from [StateUsers].
  ///
  /// The [uid] identifies which user to display, while [minimal],
  /// [labelStyle], [onDeleted], and [avatarPrefix] customize how the rendered
  /// chip behaves.
  const UserChip({
    super.key,
    required this.uid,
    this.minimal = false,
    this.labelStyle,
    this.onDeleted,
    this.avatarPrefix,
  });

  /// Stores the user identifier that [StateUsers] uses for lookup.
  ///
  /// The widget renders an empty [SizedBox] when [uid] is `null`.
  final String? uid;

  /// Determines whether the widget renders only the resolved text label.
  ///
  /// When `true`, the widget skips the [Chip] wrapper and avatar presentation.
  final bool minimal;

  /// Provides the [TextStyle] applied to the minimal text-only variant.
  ///
  /// The style is ignored when [minimal] is `false` because the full [Chip]
  /// uses its default label styling.
  final TextStyle? labelStyle;

  /// Stores the callback invoked when the chip's delete affordance is pressed.
  ///
  /// Supplying `null` leaves the chip without delete behavior.
  final Function()? onDeleted;

  /// Stores the prefix prepended to avatar image names when needed.
  ///
  /// The value is combined with the resolved avatar name only when both
  /// [avatarPrefix] and the user's avatar are not `null`.
  final String? avatarPrefix;

  /// Creates the mutable state that listens for user updates.
  ///
  /// The returned [_UserChipState] rebuilds when the surrounding
  /// [Provider]-backed [StateUsers] instance changes.
  @override
  State<UserChip> createState() => _UserChipState();
}

/// Builds the visual representation for [UserChip].
///
/// The state resolves the current user from [StateUsers] during each build so
/// the widget stays synchronized with provider updates.
class _UserChipState extends State<UserChip> {
  /// Queues the user lookup so `build` never starts a Firestore read.
  ///
  /// [StateUsers.getUser] batches every identifier requested during the same
  /// frame, so a list of chips resolves with chunked queries and a single
  /// notification instead of one read and one rebuild per chip.
  void _requestUser() {
    final uid = widget.uid;
    if (uid == null) return;
    context.read<StateUsers>().getUser(uid);
  }

  /// Requests the initial user record once the widget is mounted.
  @override
  void initState() {
    super.initState();
    _requestUser();
  }

  /// Requests the replacement user record when the parent supplies a new id.
  @override
  void didUpdateWidget(covariant UserChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) _requestUser();
  }

  /// Builds either a text label or a full [Chip] for the resolved user.
  ///
  /// The method returns an empty [SizedBox] when [UserChip.uid] is `null`,
  /// prefers the user's display name when available, and falls back to other
  /// identifiers as needed. It only reads the cache: the fetch is issued from
  /// [initState] and [didUpdateWidget].
  @override
  Widget build(BuildContext context) {
    if (widget.uid == null) return const SizedBox(width: 0, height: 0);
    final locales = AppLocalizations.of(context);
    final stateUsers = Provider.of<StateUsers>(context, listen: true);
    final user =
        stateUsers.cachedUser(widget.uid!) ??
        UserData.fromJson({'id': widget.uid, 'name': 'Unknown'});
    String label = user.id!;
    if (user.username != null) label = user.username!;
    if (user.name.isNotEmpty) label = user.name;
    if (widget.minimal) {
      return Text(
        label,
        style: widget.labelStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    String? url = user.avatar;
    if (widget.avatarPrefix != null && user.avatar != null) {
      url = '${widget.avatarPrefix}/${user.avatar}';
    }
    return MergeSemantics(
      child: Semantics(
        label: label,
        child: Chip(
          avatar: ExcludeSemantics(
            child: UserAvatar(
              key: ValueKey(url ?? 'user-chip-avatar-${user.id}'),
              avatar: url,
              firstName: user.firstName,
              lastName: user.lastName,
              name: user.name,
              presence: user.presence,
            ),
          ),
          label: ExcludeSemantics(
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
          onDeleted: widget.onDeleted,
          deleteButtonTooltipMessage: widget.onDeleted != null
              ? locales.get('label--remove-label', {'label': label})
              : null,
        ),
      ),
    );
  }
}
