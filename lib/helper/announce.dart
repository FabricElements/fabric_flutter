import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Sends a screen-reader announcement only when the platform supports it.
///
/// [SemanticsService.sendAnnouncement] is a no-op on platforms that do not
/// implement announcements, so every call site should be gated on
/// [MediaQuery.supportsAnnounceOf] first. Routing all announcements through
/// this helper keeps that guard in one place instead of repeating it.
///
/// Returns early when [context] is no longer mounted, when [message] is empty,
/// or when the ambient [MediaQuery] reports that announcements are
/// unsupported. A missing [MediaQuery] is treated as supported, because the
/// capability cannot be determined in that case.
///
/// [assertiveness] defaults to [Assertiveness.polite] so the announcement waits
/// for the screen reader to finish speaking; use [Assertiveness.assertive] only
/// for urgent, interrupting messages.
void announce(
  BuildContext context,
  String message, {
  Assertiveness assertiveness = Assertiveness.polite,
}) {
  if (!context.mounted || message.isEmpty) return;
  if (MediaQuery.maybeSupportsAnnounceOf(context) == false) return;
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
    assertiveness: assertiveness,
  );
}
