import 'dart:async';

import 'package:fabric_flutter/component/voice_dictation_button.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Fakes [SpeechToText] so widget tests never hit real platform channels.
///
/// Built from the `@visibleForTesting` generative constructor
/// [SpeechToText.withMethodChannel], which has an empty body, then overrides
/// every method the widget calls with in-memory behavior that tests can
/// drive directly via [emitResult].
class _FakeSpeechToText extends SpeechToText {
  _FakeSpeechToText() : super.withMethodChannel();

  /// Controls the value returned by [initialize].
  bool availableToReturn = true;

  /// When set, [initialize] reports this message through its `onError`
  /// callback and returns `false` from [initialize].
  String? initializeErrorMessage;

  /// When set, [listen] reports this message through the widget's registered
  /// error listener instead of starting a session.
  String? listenErrorMessage;

  /// Records whether [listen] was invoked.
  bool listenCalled = false;

  /// Records whether [stop] was invoked.
  bool stopCalled = false;

  /// Records how many times [listen] has been invoked in total.
  int listenCallCount = 0;

  /// When set, [stop] awaits this future before completing, letting tests
  /// simulate a slow platform teardown (as happens on iOS).
  Future<void>? stopDelay;

  /// Records whether [cancel] was invoked.
  bool cancelCalled = false;

  SpeechErrorListener? _errorListener;
  SpeechResultListener? _resultListener;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = const Duration(seconds: 2),
    List<SpeechConfigOption>? options,
  }) async {
    _errorListener = onError;
    if (initializeErrorMessage != null) {
      onError?.call(SpeechRecognitionError(initializeErrorMessage!, false));
      return false;
    }
    return availableToReturn;
  }

  @override
  Future listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    if (listenErrorMessage != null) {
      _errorListener?.call(SpeechRecognitionError(listenErrorMessage!, false));
      return;
    }
    listenCalled = true;
    listenCallCount++;
    _resultListener = onResult;
  }

  /// Simulates the recognizer reporting recognized [words] to whatever
  /// listener was registered by the widget's last [listen] call.
  void emitResult(String words, {bool isFinal = false}) {
    _resultListener?.call(
      SpeechRecognitionResult([
        SpeechRecognitionWords(words, null, 1),
      ], isFinal ? ResultType.finalResult.value : ResultType.partial.value),
    );
  }

  /// Simulates the recognizer's persistent error listener firing with
  /// [message], as happens when a native session reports a delayed
  /// teardown error (e.g. iOS `error_unknown (300)`) independent of any
  /// [listen] call currently in flight.
  void emitError(String message) {
    _errorListener?.call(SpeechRecognitionError(message, false));
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
    final delay = stopDelay;
    if (delay != null) {
      await delay;
    }
  }

  @override
  Future<void> cancel() async {
    cancelCalled = true;
  }
}

void main() {
  group('VoiceDictationButton', () {
    testWidgets(
      'should start listening and report availability on pointer down',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText();
        var listening = false;
        bool? available;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceDictationButton(
                speechToText: fake,
                onPartialTranscript: (_) {},
                onFinalTranscript: (_) {},
                onListeningChanged: (value) => listening = value,
                onAvailabilityChanged: (value) => available = value,
              ),
            ),
          ),
        );

        // Act
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(available, isTrue);
        expect(listening, isTrue);
        expect(fake.listenCalled, isTrue);

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'should color the icon with the default color until availability is '
      'known, primary once available, and error while listening',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText();
        late ThemeData theme;

        Icon getIcon() => tester.widget<Icon>(find.byType(Icon));

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                theme = Theme.of(context);
                return Scaffold(
                  body: VoiceDictationButton(
                    speechToText: fake,
                    onPartialTranscript: (_) {},
                    onFinalTranscript: (_) {},
                  ),
                );
              },
            ),
          ),
        );

        // Assert: before any availability check, the icon uses the default
        // (unset) color.
        expect(getIcon().color, isNull);

        // Act: press to trigger availability check and start listening.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();

        // Assert: while listening, the icon uses the error color.
        expect(getIcon().color, theme.colorScheme.error);

        // Act: release to stop listening, keeping availability known.
        await gesture.up();
        await tester.pumpAndSettle();

        // Assert: once available (but idle), the icon uses the primary
        // color to hint readiness.
        expect(getIcon().color, theme.colorScheme.primary);
      },
    );

    testWidgets('should localize the tooltip instead of hardcoding it', (
      WidgetTester tester,
    ) async {
      // Arrange
      final fake = _FakeSpeechToText();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizationsDelegate(locales: {})],
          home: Scaffold(
            body: VoiceDictationButton(
              speechToText: fake,
              onPartialTranscript: (_) {},
              onFinalTranscript: (_) {},
            ),
          ),
        ),
      );

      // Assert: idle tooltip resolves through AppLocalizations.
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hold to dictate'), findsOneWidget);

      // Act: press and hold to switch into the listening state.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IconButton)),
      );
      await tester.pumpAndSettle();

      // Assert: listening tooltip also resolves through AppLocalizations.
      expect(find.byTooltip('Listening…'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'should wait for a slow platform stop() to finish before starting the next session '
      '(regression for iOS error_unknown (300))',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText();
        final stopCompleter = Completer<void>();
        fake.stopDelay = stopCompleter.future;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceDictationButton(
                speechToText: fake,
                onPartialTranscript: (_) {},
                onFinalTranscript: (_) {},
              ),
            ),
          ),
        );

        // Act: first press/release starts a session then requests a stop
        // that never completes until the test allows it to.
        final firstPress = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();
        expect(fake.listenCallCount, 1);
        await firstPress.up();
        await tester.pump();
        expect(fake.stopCalled, isTrue);

        // Act: press again immediately, before the first stop() resolves.
        final secondPress = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pump();

        // Assert: the widget must not start a new session until the
        // pending stop() has finished — starting too soon is what triggers
        // iOS's `error_unknown (300)`.
        expect(fake.listenCallCount, 1);

        // Act: let the first stop() resolve.
        stopCompleter.complete();
        await tester.pumpAndSettle();

        // Assert: only now does the second session start.
        expect(fake.listenCallCount, 2);

        await secondPress.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('should stream growing partial transcripts while held', (
      WidgetTester tester,
    ) async {
      // Arrange
      final fake = _FakeSpeechToText();
      final partials = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceDictationButton(
              speechToText: fake,
              onPartialTranscript: partials.add,
              onFinalTranscript: (_) {},
            ),
          ),
        ),
      );

      // Act
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IconButton)),
      );
      await tester.pumpAndSettle();
      fake.emitResult('hello');
      fake.emitResult('hello world');

      // Assert
      expect(partials, ['hello', 'hello world']);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'should stop listening and report the trimmed final transcript once on release',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText();
        var listening = true;
        final finals = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceDictationButton(
                speechToText: fake,
                onPartialTranscript: (_) {},
                onFinalTranscript: finals.add,
                onListeningChanged: (value) => listening = value,
              ),
            ),
          ),
        );

        // Act
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();
        fake.emitResult('  hello world  ');
        await gesture.up();
        await tester.pumpAndSettle();

        // Assert
        expect(listening, isFalse);
        expect(fake.stopCalled, isTrue);
        expect(finals, ['hello world']);
      },
    );

    testWidgets(
      'should ignore results that arrive after the button was released',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText();
        final partials = <String>[];
        final finals = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceDictationButton(
                speechToText: fake,
                onPartialTranscript: partials.add,
                onFinalTranscript: finals.add,
              ),
            ),
          ),
        );

        // Act
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();
        fake.emitResult('hello');
        await gesture.up();
        await tester.pumpAndSettle();
        fake.emitResult('hello world late');

        // Assert
        expect(partials, ['hello']);
        expect(finals, ['hello']);
      },
    );

    testWidgets(
      'should report an error and never throw when initialize fails',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText()
          ..initializeErrorMessage = 'permission denied';
        final errors = <String>[];
        var available = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceDictationButton(
                speechToText: fake,
                onPartialTranscript: (_) {},
                onFinalTranscript: (_) {},
                onAvailabilityChanged: (value) => available = value,
                onError: errors.add,
              ),
            ),
          ),
        );

        // Act
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(errors, ['permission denied']);
        expect(available, isFalse);
        expect(fake.listenCalled, isFalse);
        expect(tester.takeException(), isNull);

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'should ignore a delayed teardown error that arrives after the button '
      'was already released (regression for iOS error_unknown (300))',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText();
        final errors = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceDictationButton(
                speechToText: fake,
                onPartialTranscript: (_) {},
                onFinalTranscript: (_) {},
                onError: errors.add,
              ),
            ),
          ),
        );

        // Act: press, release (stop requested), then simulate the native
        // side reporting a stray teardown error afterwards — the same
        // scenario that surfaced `error_unknown (300)` on iOS.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();
        await gesture.up();
        await tester.pumpAndSettle();
        fake.emitError('error_unknown (300)');
        await tester.pumpAndSettle();

        // Assert
        expect(errors, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'should still report and stop on a genuine error that arrives while '
      'actively listening',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText();
        final errors = <String>[];
        var listening = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceDictationButton(
                speechToText: fake,
                onPartialTranscript: (_) {},
                onFinalTranscript: (_) {},
                onListeningChanged: (value) => listening = value,
                onError: errors.add,
              ),
            ),
          ),
        );

        // Act
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();
        expect(listening, isTrue);
        fake.emitError('error_speech_recognizer_request_not_authorized');
        await tester.pumpAndSettle();

        // Assert
        expect(errors, ['error_speech_recognizer_request_not_authorized']);
        expect(listening, isFalse);

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'should be a no-op and never call startListening when unavailable',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText()..availableToReturn = false;
        var listening = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceDictationButton(
                speechToText: fake,
                onPartialTranscript: (_) {},
                onFinalTranscript: (_) {},
                onListeningChanged: (value) => listening = value,
              ),
            ),
          ),
        );

        // Act
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(fake.listenCalled, isFalse);
        expect(listening, isFalse);

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'should stop the recognizer without throwing when disposed while listening',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceDictationButton(
                speechToText: fake,
                onPartialTranscript: (_) {},
                onFinalTranscript: (_) {},
              ),
            ),
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();
        expect(fake.listenCalled, isTrue);

        // Act: replace the tree so the widget disposes while still listening.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pumpAndSettle();

        // Assert
        expect(fake.cancelCalled, isTrue);
        expect(tester.takeException(), isNull);

        await gesture.up();
      },
    );

    testWidgets(
      'should catch a throwing onPartialTranscript and report it via onError',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText();
        final errors = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceDictationButton(
                speechToText: fake,
                onPartialTranscript: (_) => throw StateError('boom partial'),
                onFinalTranscript: (_) {},
                onError: errors.add,
              ),
            ),
          ),
        );

        // Act
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();
        fake.emitResult('hello');

        // Assert
        expect(errors, ['Bad state: boom partial']);
        expect(tester.takeException(), isNull);

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'should catch a throwing onFinalTranscript and report it via onError',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText();
        final errors = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceDictationButton(
                speechToText: fake,
                onPartialTranscript: (_) {},
                onFinalTranscript: (_) => throw StateError('boom final'),
                onError: errors.add,
              ),
            ),
          ),
        );

        // Act
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();
        fake.emitResult('hello');
        await gesture.up();
        await tester.pumpAndSettle();

        // Assert
        expect(errors, ['Bad state: boom final']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'should catch a throwing onListeningChanged and report it via onError',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText();
        final errors = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceDictationButton(
                speechToText: fake,
                onPartialTranscript: (_) {},
                onFinalTranscript: (_) {},
                onListeningChanged: (_) => throw StateError('boom listening'),
                onError: errors.add,
              ),
            ),
          ),
        );

        // Act
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();

        // Assert: thrown on the listening-started notification.
        expect(errors, ['Bad state: boom listening']);
        expect(tester.takeException(), isNull);

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'should catch a throwing onAvailabilityChanged and report it via '
      'onError',
      (WidgetTester tester) async {
        // Arrange
        final fake = _FakeSpeechToText();
        final errors = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceDictationButton(
                speechToText: fake,
                onPartialTranscript: (_) {},
                onFinalTranscript: (_) {},
                onAvailabilityChanged: (_) =>
                    throw StateError('boom availability'),
                onError: errors.add,
              ),
            ),
          ),
        );

        // Act
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(errors, ['Bad state: boom availability']);
        expect(tester.takeException(), isNull);

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('should never throw when onError itself throws', (
      WidgetTester tester,
    ) async {
      // Arrange
      final fake = _FakeSpeechToText()
        ..initializeErrorMessage = 'permission denied';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceDictationButton(
              speechToText: fake,
              onPartialTranscript: (_) {},
              onFinalTranscript: (_) {},
              onError: (_) => throw StateError('boom onError'),
            ),
          ),
        ),
      );

      // Act
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IconButton)),
      );
      await tester.pumpAndSettle();

      // Assert: a throwing onError is swallowed instead of crashing the
      // widget — there is nowhere further to report that failure.
      expect(tester.takeException(), isNull);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
