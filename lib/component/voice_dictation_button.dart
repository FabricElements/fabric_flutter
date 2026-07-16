import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  /// Tracks the in-flight [SpeechToText.stop] call from the previous
  /// session, if any.
  ///
  /// iOS (`kAFAssistantErrorDomain`) reports `error_unknown (300)` when a new
  /// recognition session is requested before the platform has fully
  /// finished tearing down the previous one. Awaiting this future at the
  /// start of the next session avoids that race.
  Future<void>? _pendingStop;

  /// Holds the most recent recognized words so the pointer-up handler can
  /// send a trimmed final transcript even if the recognizer never reports a
  /// [SpeechRecognitionResult.finalResult].
  String _lastTranscript = '';

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
  /// lifecycle.
  void _reportListening(bool listening) {
    try {
      widget.onListeningChanged?.call(listening);
    } catch (error) {
      _reportError('$error');
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

      _lastTranscript = '';
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
    } finally {
      _starting = false;
    }
  }

  /// Reports a recognized speech result, guarding against results that
  /// arrive after listening has already stopped.
  void _handleResult(SpeechRecognitionResult result) {
    if (!_listening) return;
    _lastTranscript = result.recognizedWords;
    _reportPartialTranscript(_lastTranscript);
  }

  /// Reports a recognizer error, ignoring errors that arrive once no
  /// session is being requested or actively listened to.
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
    _reportError(error.errorMsg);
    _stopListening();
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

    final finalTranscript = _lastTranscript.trim();
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
