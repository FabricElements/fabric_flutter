import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/log_color.dart';

/// Renders a press-and-hold microphone button that streams speech
/// dictation results back to the caller through callbacks.
///
/// [VoiceDictationButton] never touches app-level state management (no
/// `Provider`/`Bloc`/`ChangeNotifier` writes) and never holds a
/// `TextEditingController` — it only reports transcripts and status through
/// [onPartialTranscript], [onFinalTranscript], [onListeningChanged],
/// [onAvailabilityChanged], and [onError]. Callers decide what to do with the
/// text, including whether/when to submit it.
///
/// Press and hold the icon to start listening; release to stop and receive
/// the final transcript. The gesture is implemented with [Listener] rather
/// than `GestureDetector.onLongPress` so the microphone reacts immediately on
/// pointer down instead of after the ~500ms long-press activation delay.
///
/// Platform notes:
/// - Android requires `android.permission.RECORD_AUDIO` (and `INTERNET` if
///   the recognizer relies on a network-based engine) declared in the
///   consuming app's `AndroidManifest.xml`.
/// - iOS requires `NSMicrophoneUsageDescription` and
///   `NSSpeechRecognitionUsageDescription` entries in the consuming app's
///   `Info.plist`.
/// - Web requires HTTPS (or `localhost`) and a genuine user gesture to
///   trigger the microphone permission prompt; the pointer-down handler
///   satisfies the gesture requirement. Browser support for the Web Speech
///   API is inconsistent — Safari and Firefox may report unavailable via
///   [onAvailabilityChanged] rather than supporting dictation like
///   Chrome/Edge.
class VoiceDictationButton extends StatefulWidget {
  /// Creates a [VoiceDictationButton].
  ///
  /// [onPartialTranscript] and [onFinalTranscript] are required so the
  /// caller always has a way to receive recognized text. The remaining
  /// callbacks are optional hooks for listening/availability/error state.
  const VoiceDictationButton({
    super.key,
    required this.onPartialTranscript,
    required this.onFinalTranscript,
    this.onListeningChanged,
    this.onAvailabilityChanged,
    this.onError,
    this.localeId,
    this.enableHapticFeedback = true,
    @visibleForTesting this.speechToText,
  });

  /// Fires repeatedly with the live, in-progress transcript while the
  /// button is held and speech is being recognized.
  final ValueChanged<String> onPartialTranscript;

  /// Fires once with the final transcript when the button is released (or
  /// recognition completes), so the caller can auto-submit it.
  final ValueChanged<String> onFinalTranscript;

  /// Fires whenever active listening starts or stops.
  ///
  /// Optional — omit if the parent doesn't need to react to listening state.
  final ValueChanged<bool>? onListeningChanged;

  /// Fires once availability is known (permission + device/browser support).
  ///
  /// Optional.
  final ValueChanged<bool>? onAvailabilityChanged;

  /// Fires on any recognition/permission error with a human-readable
  /// message.
  ///
  /// Optional — if omitted, errors are swallowed silently after stopping
  /// listening.
  final ValueChanged<String>? onError;

  /// Overrides the locale passed to the recognizer (e.g. `'en_US'`).
  final String? localeId;

  /// Whether to trigger a haptic tap ([HapticFeedback.mediumImpact] on
  /// start, [HapticFeedback.lightImpact] on stop) when listening genuinely
  /// starts/stops.
  ///
  /// Transparent internal restarts after a benign end-of-session error (see
  /// `_handleError`) do not re-trigger it, since from the caller's/user's
  /// perspective dictation never stopped. Defaults to `true`; set to
  /// `false` if the parent already provides its own feedback or the
  /// platform/device doesn't support haptics.
  final bool enableHapticFeedback;

  /// Substitutes the [SpeechToText] instance used by this widget.
  ///
  /// Intended only for tests, which inject a fake built from
  /// [SpeechToText.withMethodChannel] to avoid hitting real platform
  /// channels.
  @visibleForTesting
  final SpeechToText? speechToText;

  /// Creates the mutable state that drives the recognizer lifecycle.
  @override
  State<VoiceDictationButton> createState() => _VoiceDictationButtonState();
}

/// Coordinates [SpeechToText] listening sessions for [VoiceDictationButton].
class _VoiceDictationButtonState extends State<VoiceDictationButton> {
  /// Reuses a single recognizer instance across presses instead of
  /// recreating it every time, per `speech_to_text` guidance.
  late final SpeechToText _speech = widget.speechToText ?? SpeechToText();

  /// Tracks whether this widget currently believes it is actively listening.
  ///
  /// Flipped to `false` the instant pointer-up fires so any late/async
  /// recognizer callback can be ignored instead of reporting stale results.
  bool _listening = false;

  /// Guards against re-entrant start attempts (e.g. a stray extra
  /// pointer-down while a session is still being requested).
  bool _starting = false;

  /// Guards against overlapping restart attempts when the native task ends
  /// benignly (see [_isBenignErrorMessage]) more than once in quick
  /// succession while the button is still held.
  bool _restarting = false;

  /// Counts consecutive benign-error restarts (see [_handleError]) that
  /// happened without a single recognition result landing in between.
  ///
  /// A transient hiccup (one benign error, then real words) resets this to
  /// zero via [_handleResult]. But if the recognizer keeps ending
  /// immediately on every restart — e.g. a broken audio route/permission
  /// state that always fails the same way — blindly retrying forever would
  /// leave the button silently stuck "listening" forever without ever
  /// producing a transcript or telling the caller why. Once
  /// [_maxConsecutiveBenignRestarts] is reached the error is finally
  /// reported via [onError] and the session is stopped instead of retried
  /// again.
  int _consecutiveBenignRestarts = 0;

  /// See [_consecutiveBenignRestarts].
  static const int _maxConsecutiveBenignRestarts = 3;

  /// Tracks the in-flight [SpeechToText.stop] call from the previous
  /// session, if any.
  ///
  /// iOS (`kAFAssistantErrorDomain`) reports `error_unknown (300)` when a new
  /// recognition session is requested before the platform has fully
  /// finished tearing down the previous one. Awaiting this future at the
  /// start of the next session avoids that race.
  Future<void>? _pendingStop;

  /// Holds recognized words from segments that already ended (either a
  /// benign task restart — see [_handleError] — or a genuine
  /// [SpeechRecognitionResult.finalResult]), so they aren't lost when a new
  /// recognizer task starts fresh recognition for the next segment of the
  /// same press-and-hold session.
  String _committedTranscript = '';

  /// Holds the words recognized so far in the *current* recognizer task
  /// (since the last [_startListening]/restart), before being combined with
  /// [_committedTranscript] via [_currentTranscript].
  String _currentSegment = '';

  /// The full transcript for the in-progress press-and-hold session:
  /// everything already committed from prior segments plus whatever the
  /// current segment has recognized so far.
  String get _currentTranscript => [
    _committedTranscript,
    _currentSegment,
  ].where((segment) => segment.isNotEmpty).join(' ');

  /// Tracks whether the recognizer is currently known to be available
  /// (permission granted + device/browser support), so the icon can hint
  /// readiness with [ColorScheme.primary] instead of the default color.
  bool _available = false;

  /// Invokes [widget.onAvailabilityChanged] safely, routing any exception it
  /// throws to [_reportError] instead of letting it crash the recognizer
  /// lifecycle.
  void _reportAvailability(bool available) {
    try {
      widget.onAvailabilityChanged?.call(available);
    } catch (error) {
      _reportError('$error');
    }
  }

  /// Invokes [widget.onListeningChanged] safely, routing any exception it
  /// throws to [_reportError] instead of letting it crash the recognizer
  /// lifecycle. Also triggers a haptic tap for the transition (see
  /// [_triggerHapticFeedback]) unless [widget.enableHapticFeedback] is
  /// `false`.
  void _reportListening(bool listening) {
    _triggerHapticFeedback(listening);
    try {
      widget.onListeningChanged?.call(listening);
    } catch (error) {
      _reportError('$error');
    }
  }

  /// Fires a short haptic tap for a genuine listening start/stop transition
  /// — [HapticFeedback.mediumImpact] when [listening] starts, the lighter
  /// [HapticFeedback.lightImpact] when it stops — so the user gets tactile
  /// confirmation without needing to watch the icon. Skipped entirely when
  /// [widget.enableHapticFeedback] is `false`.
  ///
  /// Never called for the transparent internal restarts triggered by a
  /// benign end-of-session error (see `_handleError`), since dictation
  /// never actually stopped from the user's perspective. Failures (e.g. no
  /// haptic engine on the device) are caught and only logged under
  /// [kDebugMode] rather than surfaced via [onError], since a missing
  /// haptic tap isn't a dictation failure.
  void _triggerHapticFeedback(bool listening) {
    if (!widget.enableHapticFeedback) return;
    unawaited(_performHapticFeedback(listening));
  }

  /// Performs the actual platform call for [_triggerHapticFeedback],
  /// isolated into its own `async` method so a failure (e.g. no haptic
  /// engine on the device) can be awaited and caught here rather than
  /// escaping as an unhandled Future error.
  Future<void> _performHapticFeedback(bool listening) async {
    try {
      await (listening
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.lightImpact());
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          LogColor.error('VoiceDictationButton haptic failed: $error'),
        );
      }
    }
  }

  /// Invokes [widget.onPartialTranscript] safely, routing any exception it
  /// throws to [_reportError] instead of letting it crash the recognizer
  /// lifecycle.
  void _reportPartialTranscript(String transcript) {
    try {
      widget.onPartialTranscript(transcript);
    } catch (error) {
      _reportError('$error');
    }
  }

  /// Invokes [widget.onFinalTranscript] safely, routing any exception it
  /// throws to [_reportError] instead of letting it crash the recognizer
  /// lifecycle.
  void _reportFinalTranscript(String transcript) {
    try {
      widget.onFinalTranscript(transcript);
    } catch (error) {
      _reportError('$error');
    }
  }

  /// Invokes [widget.onError] safely.
  ///
  /// There is nowhere further to report a failure of the error callback
  /// itself, so it is only logged via [debugPrint] under [kDebugMode] rather
  /// than rethrown.
  void _reportError(String message) {
    try {
      widget.onError?.call(message);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          LogColor.error('VoiceDictationButton.onError threw: $error'),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_listening) {
      _listening = false;
      // Best effort: stop any dangling active session. The result is
      // intentionally ignored because the widget is being torn down.
      unawaited(_speech.cancel());
    }
    super.dispose();
  }

  /// Requests microphone permission/availability and starts a listening
  /// session, ignoring the attempt entirely when the recognizer reports
  /// unavailable rather than throwing.
  Future<void> _startListening() async {
    // Ignore re-entrant taps: a session is already active or already being
    // requested.
    if (_listening || _starting) return;
    _starting = true;
    try {
      // Wait for any previous session's stop() to fully complete before
      // asking the platform to start a new one (see [_pendingStop]).
      final pendingStop = _pendingStop;
      if (pendingStop != null) {
        try {
          await pendingStop;
        } catch (_) {
          // Ignore — we only care that the previous session finished
          // tearing down before starting a new one.
        }
      }
      if (!mounted) return;

      _committedTranscript = '';
      _currentSegment = '';
      _consecutiveBenignRestarts = 0;
      var available = false;
      try {
        // `speech_to_text` only honors the `onError`/`onStatus` callbacks
        // passed to the *first* successful `initialize()` call for the
        // lifetime of the singleton — every later call is a no-op that
        // just returns the cached availability. That means `_handleError`
        // stays registered as the sole error listener across every future
        // press, so it must guard itself (see [_handleError]) rather than
        // relying on being re-registered per session.
        available = await _speech.initialize(
          onError: _handleError,
          onStatus: (_) {},
        );
      } catch (error) {
        _reportError('$error');
        available = false;
      }
      _reportAvailability(available);
      if (mounted) setState(() => _available = available);
      if (!available) return;
      // The widget may have been unmounted/released while awaiting
      // initialization.
      if (!mounted) return;

      setState(() => _listening = true);
      _reportListening(true);
      await _requestListenSession();
    } finally {
      _starting = false;
    }
  }

  /// Requests a single `listen()` task from the recognizer, used both for
  /// the initial press and to transparently restart dictation (see
  /// [_handleError]) when the native task ends benignly (e.g. the
  /// platform's own end-of-utterance/pause timeout) while the button is
  /// still held.
  Future<void> _requestListenSession() async {
    try {
      await _speech.listen(
        onResult: _handleResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          localeId: widget.localeId,
        ),
      );
    } catch (error) {
      _reportError('$error');
      _stopListening();
    }
  }

  /// Reports a recognized speech result, guarding against results that
  /// arrive after listening has already stopped.
  ///
  /// Combines the current recognizer task's words with anything already
  /// [_committedTranscript] from prior segments (see [_currentTranscript])
  /// so a benign task restart doesn't drop previously dictated words. Also
  /// resets [_consecutiveBenignRestarts], since a real result proves the
  /// current task is actually producing audio/recognition rather than
  /// failing repeatedly.
  void _handleResult(SpeechRecognitionResult result) {
    if (!_listening) return;
    _consecutiveBenignRestarts = 0;
    _currentSegment = result.recognizedWords;
    _reportPartialTranscript(_currentTranscript);
  }

  /// Error messages the underlying `speech_to_text` platform code emits for
  /// conditions that are expected/benign rather than actionable failures —
  /// they represent a recognition task ending without a conclusive result
  /// (either genuinely, e.g. the platform's own end-of-utterance/pause
  /// timeout, or as a *stale* signal from a just-finished previous session,
  /// since the persistent error listener — see below — cannot tell which
  /// session an event actually belongs to) rather than a real
  /// permission/config/network problem.
  ///
  /// iOS reports these (and any other unmapped code, hence the
  /// [_isBenignErrorMessage] prefix check below) whenever a recognition task
  /// finishes "unsuccessfully" — which happens routinely on ordinary
  /// press-and-release usage (short holds, brief pauses, or the system's own
  /// end-of-utterance detection) and is *not* something the end user needs
  /// to be told about via [onError]. These never notify [widget.onError];
  /// while the button is still held (see [_handleError]) the session is
  /// transparently restarted instead of being stopped, so a benign,
  /// genuine task end doesn't silently cut dictation short, and stale
  /// leftover noise from a just-finished previous session doesn't
  /// interrupt a session that only just began. This was the actual cause
  /// behind the recurring `error_unknown (300)` reports
  /// (`kAFAssistantErrorDomain`), since that code is simply Apple's
  /// catch-all for "task finished without a match", not a fatal condition
  /// worth interrupting dictation for.
  static const Set<String> _benignErrorMessages = {
    'error_no_match',
    'error_speech_timeout',
    'error_busy',
    'error_client',
    'error_retry',
    'error_request_cancelled',
    'error_speech_recognizer_already_active',
    'error_speech_recognizer_connection_invalidated',
    'error_speech_recognizer_connection_interrupted',
  };

  /// Returns whether [errorMsg] represents a benign end-of-session signal
  /// (see [_benignErrorMessages]) that should never be surfaced via
  /// [onError], rather than an actionable failure the caller should be
  /// notified about and that should stop the current session outright.
  bool _isBenignErrorMessage(String errorMsg) =>
      _benignErrorMessages.contains(errorMsg) ||
      errorMsg.startsWith('error_unknown');

  /// Reports a recognizer error, ignoring errors that arrive once no
  /// session is being requested or actively listened to.
  ///
  /// Benign end-of-session codes (see [_isBenignErrorMessage]) never notify
  /// [widget.onError] on their own. If the button is still actively held
  /// ([_listening]), the recognizer task is transparently restarted via
  /// [_requestListenSession] so dictation keeps going instead of the mic
  /// silently going dead until release — this is what actually fixes
  /// `error_unknown (300)`, since on some devices this code reflects the
  /// *current* task genuinely ending (e.g. the platform's own
  /// end-of-utterance/pause timeout), not just stale noise from a previous
  /// one. Only genuinely actionable errors (permission/config/network/
  /// assets/locale) are reported and stop the session immediately.
  ///
  /// If benign errors keep recurring back-to-back without a single result
  /// landing in between (see [_consecutiveBenignRestarts]), retrying is no
  /// longer assumed to be transient — the recognizer is likely stuck (e.g.
  /// a broken audio route) — so the error is finally reported via
  /// [onError] and the session stops instead of restarting forever in
  /// silence.
  ///
  /// The native iOS session can emit a delayed teardown error (for example
  /// `error_unknown (300)` from `kAFAssistantErrorDomain`) once
  /// [SpeechToText.stop] has already resolved and the button has been
  /// released. Because `initialize`'s `onError` callback is registered only
  /// once for the lifetime of the underlying [SpeechToText] singleton — every
  /// later `initialize()` call is a no-op per `speech_to_text` semantics —
  /// this same closure keeps receiving events for every future session, so
  /// it must discard anything that isn't tied to a session currently being
  /// requested ([_starting]) or actively listened to ([_listening]).
  void _handleError(SpeechRecognitionError error) {
    if (!_starting && !_listening) return;
    if (_isBenignErrorMessage(error.errorMsg)) {
      if (!_listening || _restarting) return;
      _consecutiveBenignRestarts++;
      if (_consecutiveBenignRestarts > _maxConsecutiveBenignRestarts) {
        _reportError(error.errorMsg);
        _stopListening();
        return;
      }
      unawaited(_restartListening());
      return;
    }
    _reportError(error.errorMsg);
    _stopListening();
  }

  /// Transparently requests a fresh [SpeechToText.listen] task after a
  /// benign task end (see [_handleError]), without touching [_listening] or
  /// firing [onListeningChanged] — from the caller's perspective dictation
  /// never stopped.
  ///
  /// Commits whatever the just-ended task had recognized into
  /// [_committedTranscript] first, since the new task starts fresh
  /// recognition and would otherwise report only the next segment's words,
  /// silently dropping everything dictated before the restart.
  Future<void> _restartListening() async {
    _restarting = true;
    try {
      if (!mounted || !_listening) return;
      if (_currentSegment.isNotEmpty) {
        _committedTranscript = _currentTranscript;
        _currentSegment = '';
      }
      await _requestListenSession();
    } finally {
      _restarting = false;
    }
  }

  /// Stops the active listening session and reports the last known
  /// transcript as final.
  ///
  /// Marks [_listening] `false` before calling into the recognizer so any
  /// result that was already in flight is discarded by [_handleResult]. The
  /// resulting [SpeechToText.stop] future is retained in [_pendingStop] so
  /// the next [_startListening] call can wait for it, avoiding the iOS
  /// `error_unknown (300)` race described there.
  void _stopListening() {
    if (!_listening) return;
    setState(() => _listening = false);
    _reportListening(false);
    _pendingStop = _speech.stop();

    final finalTranscript = _currentTranscript.trim();
    if (finalTranscript.isNotEmpty) {
      _reportFinalTranscript(finalTranscript);
    }
  }

  /// Builds the microphone icon button wrapped in a [Listener] so the
  /// press-and-hold gesture activates immediately on pointer down instead of
  /// after the long-press delay.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locales = AppLocalizations.of(context);
    return Listener(
      onPointerDown: (_) => _startListening(),
      onPointerUp: (_) => _stopListening(),
      onPointerCancel: (_) => _stopListening(),
      child: IconButton(
        onPressed: () {},
        // The widget already drives its own precise start/stop haptic taps
        // via [_triggerHapticFeedback]; suppress IconButton's own built-in
        // tap feedback so Android doesn't fire an extra, generic vibration
        // on top of ours.
        enableFeedback: false,
        tooltip: _listening
            ? locales.get('label--listening')
            : locales.get('label--hold-to-dictate'),
        icon: Icon(
          _listening ? Icons.mic : Icons.mic_none,
          color: _listening
              ? theme.colorScheme.error
              : (_available ? theme.colorScheme.primary : null),
        ),
      ),
    );
  }
}
