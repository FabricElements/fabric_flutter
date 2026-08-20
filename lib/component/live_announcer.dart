import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Announces transient state changes to assistive technology exactly once.
///
/// Screen readers only speak content that is focused or that arrives inside a
/// live region. Transient state — "3 results found", "Saving…", a validation
/// summary, a connectivity change — usually never receives focus, so it is
/// silently missed. [LiveAnnouncer] solves that with two complementary
/// mechanisms, which is why both are used together:
///
/// * **[Semantics.liveRegion]** marks [child] (or the announcer's own node) as a
///   region whose changes should be surfaced automatically. It is the preferred,
///   platform-idiomatic mechanism: it is non-disruptive, respects the user's
///   verbosity settings, and is what Android's accessibility framework
///   recommends now that `announceForAccessibility` is deprecated. Its downside
///   is that support and timing vary by platform, and it only fires when the
///   node is actually part of the rendered tree.
/// * **[SemanticsService.sendAnnouncement]** pushes the message directly to the
///   platform's accessibility bridge. It works even when nothing visible
///   changed, but it is disruptive (TalkBack clears its speech queue) and is not
///   supported everywhere, so it must never be spammed.
///
/// The combination gives a reliable announcement across platforms, and the
/// built-in **deduplication** is what makes it safe: [message] is announced only
/// when it *changes*. Rebuilding this widget a hundred times with the same
/// message announces once. A `null`, empty, or whitespace-only [message]
/// announces nothing and is not an error; it also resets the deduplication
/// state, so restoring the previous message announces it again.
///
/// Announcements are dispatched after the current frame and are guarded by a
/// [State.mounted] check, so a widget that is disposed while the frame is in
/// flight never announces.
///
/// ```dart
/// LiveAnnouncer(
///   message: state.loading ? 'Loading results' : '${state.items.length} results',
///   child: ResultsList(items: state.items),
/// );
/// ```
///
/// Use [assertiveness] to interrupt the user for genuinely urgent messages, and
/// [announce] / [liveRegion] to opt out of either mechanism when a host
/// application only wants one of them.
class LiveAnnouncer extends StatefulWidget {
  /// Creates a [LiveAnnouncer] that speaks [message] whenever it changes.
  ///
  /// [child] is optional so the announcer can be dropped anywhere in a tree —
  /// including inside a [Stack] or a [Column] — purely to announce state that is
  /// rendered elsewhere.
  const LiveAnnouncer({
    super.key,
    required this.message,
    this.child,
    this.assertiveness = Assertiveness.polite,
    this.announce = true,
    this.liveRegion = true,
  });

  /// Stores the message announced to assistive technology.
  ///
  /// Announced only when the value differs from the previously announced one.
  /// `null`, empty, and whitespace-only values announce nothing.
  final String? message;

  /// Stores the optional subtree rendered inside the live region.
  ///
  /// Defaults to an empty box when `null`, so the announcer occupies no space
  /// and can be used as a pure side effect.
  final Widget? child;

  /// Stores how urgently the platform should deliver the announcement.
  ///
  /// [Assertiveness.assertive] interrupts whatever the screen reader is saying
  /// and is currently honored on the web engine only. Defaults to
  /// [Assertiveness.polite].
  final Assertiveness assertiveness;

  /// Controls whether [SemanticsService.sendAnnouncement] is used.
  ///
  /// Set to `false` to rely on the [liveRegion] node alone, for example on
  /// Android where direct announcements are discouraged.
  final bool announce;

  /// Controls whether the rendered node is marked as a live region.
  ///
  /// Set to `false` to send a one-shot announcement without publishing a
  /// permanent live region into the semantics tree.
  final bool liveRegion;

  /// Creates the mutable [State] used to track the announced message.
  ///
  /// Returns a [_LiveAnnouncerState] so deduplication survives rebuilds.
  @override
  State<LiveAnnouncer> createState() => _LiveAnnouncerState();
}

/// Holds the deduplication state for [LiveAnnouncer].
///
/// Remembers the last message handed to the platform so an unchanged message is
/// never announced twice, and schedules announcements after the current frame.
class _LiveAnnouncerState extends State<LiveAnnouncer> {
  /// Stores the last message that was actually announced.
  ///
  /// Compared against the incoming [LiveAnnouncer.message] to suppress repeats.
  String? _announced;

  /// Announces the initial message when the widget enters the tree.
  ///
  /// Uses a post-frame callback because [View.of] and [Directionality.of]
  /// require a fully mounted element.
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  /// Announces the new message when [LiveAnnouncer.message] changes.
  ///
  /// Compares against the last announced value rather than [oldWidget] so a
  /// message that flips away and back is still announced.
  @override
  void didUpdateWidget(covariant LiveAnnouncer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  /// Returns the trimmed message when it is worth announcing.
  ///
  /// Yields `null` for `null`, empty, and whitespace-only messages.
  String? get _message {
    final message = widget.message?.trim();
    if (message == null || message.isEmpty) return null;
    return message;
  }

  /// Schedules an announcement for the current message when it changed.
  ///
  /// Resets the deduplication state for an empty message, skips unchanged
  /// messages, and defers the platform call to the end of the frame so it is
  /// safe to call from [initState] and [State.build] driven updates.
  void _schedule() {
    final message = _message;
    if (message == null) {
      _announced = null;
      return;
    }
    if (message == _announced) return;
    _announced = message;
    if (!widget.announce) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
        assertiveness: widget.assertiveness,
      );
    });
  }

  /// Builds the live region wrapping [LiveAnnouncer.child].
  ///
  /// Publishes the message as the node label so platforms that support live
  /// regions can re-read it without a direct announcement.
  @override
  Widget build(BuildContext context) {
    final child = widget.child ?? const SizedBox.shrink();
    final message = _message;
    if (!widget.liveRegion || message == null) return child;
    return Semantics(
      liveRegion: true,
      label: message,
      container: true,
      child: child,
    );
  }
}
