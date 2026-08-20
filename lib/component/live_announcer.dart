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
/// ## State versus events: when deduplication is wrong
///
/// Deduplication is deliberate and load-bearing for **state**: "3 results
/// found" describes a condition, so announcing it once per *change* is exactly
/// right and announcing it on every rebuild would be spam.
///
/// ```dart
/// // State: the message describes a condition. Dedup is what you want.
/// LiveAnnouncer(
///   message: state.loading ? 'Loading results' : '${state.items.length} results',
///   child: ResultsList(items: state.items),
/// );
/// ```
///
/// It is wrong for **events**. Two taps on *Send* are two distinct real-world
/// occurrences that happen to share the label "Message sent"; with pure message
/// deduplication the second one is silently dropped and the screen-reader user
/// gets no confirmation that it happened. [announcementTag] exists for that
/// case: the deduplication key becomes the pair ([message], [announcementTag])
/// instead of [message] alone, so an identical message paired with a *new* tag
/// is announced again.
///
/// ```dart
/// // Event: the same label can legitimately repeat. Tag it with the event's
/// // identity — a counter, a timestamp, or an id — so each occurrence speaks.
/// LiveAnnouncer(
///   message: sendResult, // 'Message sent'
///   announcementTag: sendAttempt, // incremented once per tap on Send
///   child: const ComposerActions(),
/// );
/// ```
///
/// A tag is used rather than a `forceRepeat` flag on purpose: a flag cannot
/// tell "this is a new event" apart from "this widget rebuilt for an unrelated
/// reason", so it would re-announce on incidental rebuilds and reintroduce the
/// spam the deduplication prevents. A tag ties re-announcement to an explicit,
/// caller-owned event identity — an unchanged tag still deduplicates, no matter
/// how often the widget rebuilds.
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
    this.announceOnMount = true,
    this.announcementTag,
  });

  /// Stores the message announced to assistive technology.
  ///
  /// Announced only when the value differs from the previously announced one,
  /// or when [announcementTag] changed. `null`, empty, and whitespace-only
  /// values announce nothing.
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

  /// Controls whether the initial [message] is announced when the widget mounts.
  ///
  /// Defaults to `true`, so a non-empty message present at first build is
  /// spoken immediately — the platform-idiomatic behavior for a live region.
  ///
  /// Set to `false` to suppress that first announcement and speak only on
  /// subsequent *transitions*. This is useful when the widget is mounted with a
  /// message that reflects already-present state (for example, opening a screen
  /// whose latest item would otherwise be read aloud on entry). When `false`,
  /// the deduplication state is seeded with the current message, so a later
  /// change to a *different* message still announces, while flipping back to the
  /// seeded value stays silent. It does not affect the rendered [liveRegion]
  /// node, only the direct [SemanticsService.sendAnnouncement] on mount.
  final bool announceOnMount;

  /// Stores the caller-owned identity of the occurrence being announced.
  ///
  /// Extends deduplication from [message] alone to the pair ([message], this
  /// value), which is what makes a *repeated event* announceable. Defaults to
  /// `null`, in which case behavior is identical to deduplicating on [message]
  /// only — existing call sites are unaffected.
  ///
  /// Pass a value that changes once per real occurrence — a send counter, a
  /// timestamp, an event id — when the same text can legitimately be announced
  /// again ("Message sent" after a second tap on *Send*). An identical message
  /// carrying a *new* tag is announced again; an identical message carrying the
  /// *same* tag is still suppressed, so incidental rebuilds never re-announce.
  ///
  /// Compared with `==`, so any value with meaningful equality works.
  final Object? announcementTag;

  /// Creates the mutable [State] used to track the announced message.
  ///
  /// Returns a [_LiveAnnouncerState] so deduplication survives rebuilds.
  @override
  State<LiveAnnouncer> createState() => _LiveAnnouncerState();
}

/// Holds the deduplication state for [LiveAnnouncer].
///
/// Remembers the last message handed to the platform, together with the tag it
/// was paired with, so an unchanged pair is never announced twice, and schedules
/// announcements after the current frame.
class _LiveAnnouncerState extends State<LiveAnnouncer> {
  /// Stores the last message that was actually announced.
  ///
  /// Compared against the incoming [LiveAnnouncer.message] to suppress repeats.
  String? _announced;

  /// Stores the tag that [_announced] was paired with when it was announced.
  ///
  /// Compared against the incoming [LiveAnnouncer.announcementTag] so an
  /// identical message carrying a new tag is announced again.
  Object? _announcedTag;

  /// Announces the initial message when the widget enters the tree.
  ///
  /// Uses a post-frame callback because [View.of] and [Directionality.of]
  /// require a fully mounted element. When [LiveAnnouncer.announceOnMount] is
  /// `false`, the deduplication state is seeded with the current message *and*
  /// tag instead, so only later transitions of either are announced.
  @override
  void initState() {
    super.initState();
    if (widget.announceOnMount) {
      _schedule();
    } else {
      _announced = _message;
      _announcedTag = widget.announcementTag;
    }
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
  /// Resets the deduplication state for an empty message, skips messages whose
  /// ([LiveAnnouncer.message], [LiveAnnouncer.announcementTag]) pair is
  /// unchanged, and defers the platform call to the end of the frame so it is
  /// safe to call from [initState] and [State.build] driven updates.
  void _schedule() {
    final message = _message;
    final tag = widget.announcementTag;
    if (message == null) {
      _announced = null;
      _announcedTag = null;
      return;
    }
    if (message == _announced && tag == _announcedTag) return;
    _announced = message;
    _announcedTag = tag;
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
