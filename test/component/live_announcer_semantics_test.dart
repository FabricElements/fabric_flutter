import 'package:fabric_flutter/component/live_announcer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in the minimal app scaffolding required to pump a component.
Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// Captures the announcements pushed through [SystemChannels.accessibility].
///
/// Installs a mock handler on the accessibility channel and collects the
/// `message` of every `announce` event, so tests can assert on what assistive
/// technology would actually receive instead of on widget fields.
class _AnnouncementRecorder {
  /// Collects the announced messages in the order they were sent.
  final List<String> messages = <String>[];

  /// Starts intercepting announcements for the given [tester].
  void start(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (dynamic message) async {
        final data = message as Map<dynamic, dynamic>?;
        if (data == null) return null;
        if (data['type'] != 'announce') return null;
        final args = data['data'] as Map<dynamic, dynamic>?;
        final value = args?['message'];
        if (value is String) messages.add(value);
        return null;
      },
    );
  }

  /// Stops intercepting announcements for the given [tester].
  void stop(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      null,
    );
  }
}

/// A scrollable form whose [State] must survive a message toggle.
///
/// Stands in for the persistent content a caller wraps in a [LiveAnnouncer]:
/// the [ScrollController] and [FocusNode] are owned by the caller so a test can
/// observe them across rebuilds, and the [State] object identity is the signal
/// that the subtree was not re-parented.
class _ScrollableForm extends StatefulWidget {
  /// Creates a scrollable form driven by an externally owned controller and
  /// focus node.
  const _ScrollableForm({required this.controller, required this.focusNode});

  /// Stores the scroll position asserted to survive a message toggle.
  final ScrollController controller;

  /// Stores the focus node asserted to survive a message toggle.
  final FocusNode focusNode;

  @override
  State<_ScrollableForm> createState() => _ScrollableFormState();
}

/// Holds the scroll view and text field that must not be rebuilt from scratch.
class _ScrollableFormState extends State<_ScrollableForm> {
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: widget.controller,
    child: Column(
      children: <Widget>[
        TextField(focusNode: widget.focusNode),
        const SizedBox(height: 1000),
      ],
    ),
  );
}

/// Removes [child] from the tree during the post-frame phase of its first frame.
///
/// Registers its post-frame callback before any descendant does, then forces a
/// synchronous rebuild so the descendant is unmounted before the descendant's
/// own post-frame callback runs.
class _DisposeDuringFrame extends StatefulWidget {
  /// Creates a host that unmounts [child] mid-frame.
  const _DisposeDuringFrame({required this.child});

  /// Stores the subtree removed during the first frame.
  final Widget child;

  @override
  State<_DisposeDuringFrame> createState() => _DisposeDuringFrameState();
}

/// Holds the visibility flag for [_DisposeDuringFrame].
class _DisposeDuringFrameState extends State<_DisposeDuringFrame> {
  /// Tracks whether the child is still part of the tree.
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = false);
      final owner = WidgetsBinding.instance.buildOwner!;
      owner.buildScope(WidgetsBinding.instance.rootElement!);
      owner.finalizeTree();
    });
  }

  @override
  Widget build(BuildContext context) =>
      _visible ? widget.child : const SizedBox.shrink();
}

void main() {
  group('LiveAnnouncer', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        supportsAnnounce: true,
      );
    });

    tearDown(() {
      TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
          .clearAccessibilityFeaturesTestValue();
    });

    group('announcements', () {
      testWidgets('should announce the initial message once', (
        WidgetTester tester,
      ) async {
        // Arrange
        final recorder = _AnnouncementRecorder()..start(tester);

        // Act
        await tester.pumpWidget(
          _app(const LiveAnnouncer(message: 'Three results found')),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(recorder.messages, <String>['Three results found']);
        recorder.stop(tester);
      });

      testWidgets('should announce an unchanged message exactly once', (
        WidgetTester tester,
      ) async {
        // Arrange
        final recorder = _AnnouncementRecorder()..start(tester);
        const widget = LiveAnnouncer(message: 'Saving');

        // Act
        await tester.pumpWidget(_app(widget));
        await tester.pumpAndSettle();
        await tester.pumpWidget(_app(const LiveAnnouncer(message: 'Saving')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(_app(const LiveAnnouncer(message: 'Saving')));
        await tester.pumpAndSettle();

        // Assert
        expect(recorder.messages, <String>['Saving']);
        recorder.stop(tester);
      });

      testWidgets('should announce again when the message changes', (
        WidgetTester tester,
      ) async {
        // Arrange
        final recorder = _AnnouncementRecorder()..start(tester);

        // Act
        await tester.pumpWidget(_app(const LiveAnnouncer(message: 'Loading')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          _app(const LiveAnnouncer(message: 'Two results')),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(recorder.messages, <String>['Loading', 'Two results']);
        recorder.stop(tester);
      });

      testWidgets('should not announce a null or blank message', (
        WidgetTester tester,
      ) async {
        // Arrange
        final recorder = _AnnouncementRecorder()..start(tester);

        // Act
        await tester.pumpWidget(_app(const LiveAnnouncer(message: null)));
        await tester.pumpAndSettle();
        await tester.pumpWidget(_app(const LiveAnnouncer(message: '   ')));
        await tester.pumpAndSettle();

        // Assert
        expect(recorder.messages, isEmpty);
        recorder.stop(tester);
      });

      testWidgets('should announce again after the message is cleared', (
        WidgetTester tester,
      ) async {
        // Arrange
        final recorder = _AnnouncementRecorder()..start(tester);

        // Act
        await tester.pumpWidget(_app(const LiveAnnouncer(message: 'Offline')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(_app(const LiveAnnouncer(message: null)));
        await tester.pumpAndSettle();
        await tester.pumpWidget(_app(const LiveAnnouncer(message: 'Offline')));
        await tester.pumpAndSettle();

        // Assert
        expect(recorder.messages, <String>['Offline', 'Offline']);
        recorder.stop(tester);
      });

      testWidgets('should not announce after the widget is unmounted', (
        WidgetTester tester,
      ) async {
        // Arrange
        final recorder = _AnnouncementRecorder()..start(tester);

        // Act
        // The host registers its post-frame callback before the announcer does,
        // so it runs first and synchronously rebuilds the tree without the
        // announcer. The announcer's own callback therefore fires while it is
        // already unmounted, which is exactly the case the mounted guard covers.
        await tester.pumpWidget(
          _app(
            const _DisposeDuringFrame(
              child: LiveAnnouncer(message: 'Disposed before the frame ends'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(recorder.messages, isEmpty);
        expect(tester.takeException(), isNull);
        recorder.stop(tester);
      });

      testWidgets('should skip announcements when announce is false', (
        WidgetTester tester,
      ) async {
        // Arrange
        final recorder = _AnnouncementRecorder()..start(tester);

        // Act
        await tester.pumpWidget(
          _app(const LiveAnnouncer(message: 'Quiet', announce: false)),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(recorder.messages, isEmpty);
        recorder.stop(tester);
      });

      testWidgets('should announce on mount when announceOnMount is true', (
        WidgetTester tester,
      ) async {
        // Arrange
        final recorder = _AnnouncementRecorder()..start(tester);

        // Act
        await tester.pumpWidget(
          _app(
            const LiveAnnouncer(
              message: 'Queue: 3 waiting',
              announceOnMount: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(recorder.messages, <String>['Queue: 3 waiting']);
        recorder.stop(tester);
      });

      testWidgets(
        'should stay silent on mount when announceOnMount is false, then '
        'speak on a genuine change while ignoring the seeded value',
        (WidgetTester tester) async {
          // Arrange
          final recorder = _AnnouncementRecorder()..start(tester);

          // Act — mount with a message reflecting already-present state.
          await tester.pumpWidget(
            _app(
              const LiveAnnouncer(
                message: 'Queue: 3 waiting',
                announceOnMount: false,
              ),
            ),
          );
          await tester.pumpAndSettle();
          // Rebuild with the same seeded message: must stay silent.
          await tester.pumpWidget(
            _app(
              const LiveAnnouncer(
                message: 'Queue: 3 waiting',
                announceOnMount: false,
              ),
            ),
          );
          await tester.pumpAndSettle();
          // A genuine transition must still announce.
          await tester.pumpWidget(
            _app(
              const LiveAnnouncer(
                message: 'Queue: 5 waiting',
                announceOnMount: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Assert
          expect(recorder.messages, <String>['Queue: 5 waiting']);
          recorder.stop(tester);
        },
      );
    });

    group('repeated events', () {
      testWidgets(
        'should announce an identical message again when the tag changes',
        (WidgetTester tester) async {
          // Arrange — the same label produced by two distinct send events.
          final recorder = _AnnouncementRecorder()..start(tester);

          // Act
          await tester.pumpWidget(
            _app(
              const LiveAnnouncer(message: 'Message sent', announcementTag: 1),
            ),
          );
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            _app(
              const LiveAnnouncer(message: 'Message sent', announcementTag: 2),
            ),
          );
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            _app(
              const LiveAnnouncer(message: 'Message sent', announcementTag: 3),
            ),
          );
          await tester.pumpAndSettle();

          // Assert
          expect(recorder.messages, <String>[
            'Message sent',
            'Message sent',
            'Message sent',
          ]);
          recorder.stop(tester);
        },
      );

      testWidgets(
        'should not re-announce an identical message with an unchanged tag',
        (WidgetTester tester) async {
          // Arrange — incidental rebuilds must not re-announce the same event.
          final recorder = _AnnouncementRecorder()..start(tester);

          // Act
          await tester.pumpWidget(
            _app(
              const LiveAnnouncer(message: 'Message sent', announcementTag: 7),
            ),
          );
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            _app(
              const LiveAnnouncer(message: 'Message sent', announcementTag: 7),
            ),
          );
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            _app(
              const LiveAnnouncer(message: 'Message sent', announcementTag: 7),
            ),
          );
          await tester.pumpAndSettle();

          // Assert
          expect(recorder.messages, <String>['Message sent']);
          recorder.stop(tester);
        },
      );

      testWidgets(
        'should keep deduplicating identical messages without a tag',
        (WidgetTester tester) async {
          // Arrange
          final recorder = _AnnouncementRecorder()..start(tester);

          // Act
          await tester.pumpWidget(
            _app(const LiveAnnouncer(message: 'Message sent')),
          );
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            _app(const LiveAnnouncer(message: 'Message sent')),
          );
          await tester.pumpAndSettle();

          // Assert
          expect(recorder.messages, <String>['Message sent']);
          recorder.stop(tester);
        },
      );

      testWidgets('should announce a different message with no tag', (
        WidgetTester tester,
      ) async {
        // Arrange
        final recorder = _AnnouncementRecorder()..start(tester);

        // Act
        await tester.pumpWidget(
          _app(const LiveAnnouncer(message: 'Message sent')),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          _app(const LiveAnnouncer(message: 'Message failed')),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(recorder.messages, <String>['Message sent', 'Message failed']);
        recorder.stop(tester);
      });

      testWidgets(
        'should stay silent on mount with a tag when announceOnMount is false, '
        'then announce the same message on a later tag change',
        (WidgetTester tester) async {
          // Arrange
          final recorder = _AnnouncementRecorder()..start(tester);

          // Act
          await tester.pumpWidget(
            _app(
              const LiveAnnouncer(
                message: 'Message sent',
                announcementTag: 1,
                announceOnMount: false,
              ),
            ),
          );
          await tester.pumpAndSettle();
          // Same message and tag: still silent.
          await tester.pumpWidget(
            _app(
              const LiveAnnouncer(
                message: 'Message sent',
                announcementTag: 1,
                announceOnMount: false,
              ),
            ),
          );
          await tester.pumpAndSettle();
          // A new event with the same label must announce.
          await tester.pumpWidget(
            _app(
              const LiveAnnouncer(
                message: 'Message sent',
                announcementTag: 2,
                announceOnMount: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Assert
          expect(recorder.messages, <String>['Message sent']);
          recorder.stop(tester);
        },
      );

      testWidgets('should reset the tagged state on a blank message', (
        WidgetTester tester,
      ) async {
        // Arrange
        final recorder = _AnnouncementRecorder()..start(tester);

        // Act
        await tester.pumpWidget(
          _app(
            const LiveAnnouncer(message: 'Message sent', announcementTag: 1),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          _app(const LiveAnnouncer(message: '   ', announcementTag: 1)),
        );
        await tester.pumpAndSettle();
        // The same message and the same tag announce again after the reset.
        await tester.pumpWidget(
          _app(
            const LiveAnnouncer(message: 'Message sent', announcementTag: 1),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(recorder.messages, <String>['Message sent', 'Message sent']);
        recorder.stop(tester);
      });

      testWidgets('should keep the live region label across tag changes', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(
          _app(
            const LiveAnnouncer(
              message: 'Message sent',
              announcementTag: 1,
              child: Text('Composer'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          _app(
            const LiveAnnouncer(
              message: 'Message sent',
              announcementTag: 2,
              child: Text('Composer'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        final node = tester.getSemantics(find.byType(LiveAnnouncer));
        expect(node.flagsCollection.isLiveRegion, isTrue);
        expect(node.label, contains('Message sent'));
        handle.dispose();
      });
    });

    group('semantics', () {
      testWidgets('should expose a live region node carrying the message', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(
          _app(
            const LiveAnnouncer(
              message: 'Five results found',
              child: Text('Results'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        final node = tester.getSemantics(find.byType(LiveAnnouncer));
        expect(node.flagsCollection.isLiveRegion, isTrue);
        expect(node.label, contains('Five results found'));
        handle.dispose();
      });

      testWidgets('should not publish a live region without a message', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(
          _app(const LiveAnnouncer(message: null, child: Text('Results'))),
        );
        await tester.pumpAndSettle();

        // Assert
        final node = tester.getSemantics(find.byType(LiveAnnouncer));
        expect(node.flagsCollection.isLiveRegion, isFalse);
        handle.dispose();
      });

      testWidgets('should not publish a live region when liveRegion is false', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(
          _app(
            const LiveAnnouncer(
              message: 'Hidden region',
              liveRegion: false,
              child: Text('Results'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        final node = tester.getSemantics(find.byType(LiveAnnouncer));
        expect(node.flagsCollection.isLiveRegion, isFalse);
        handle.dispose();
      });

      testWidgets('should render the child unchanged', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(
          _app(
            const LiveAnnouncer(message: 'Anything', child: Text('Payload')),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Payload'), findsOneWidget);
      });
    });

    group('structural stability', () {
      testWidgets(
        'should preserve the child State, focus and scroll offset when the '
        'message toggles null -> message -> null',
        (WidgetTester tester) async {
          // Arrange — persistent content holding scroll and focus state.
          final controller = ScrollController();
          addTearDown(controller.dispose);
          final focusNode = FocusNode();
          addTearDown(focusNode.dispose);

          Widget build(String? message) => _app(
            LiveAnnouncer(
              message: message,
              child: _ScrollableForm(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          );

          await tester.pumpWidget(build(null));
          await tester.pumpAndSettle();
          // Focus first: revealing the caret scrolls the field into view, so
          // the offset is established after it to observe it across toggles.
          focusNode.requestFocus();
          await tester.pumpAndSettle();
          controller.jumpTo(200);
          await tester.pumpAndSettle();

          final stateBefore = tester.state<_ScrollableFormState>(
            find.byType(_ScrollableForm),
          );
          expect(controller.offset, 200);
          expect(focusNode.hasFocus, isTrue);

          // Act — the message appears, then disappears again.
          await tester.pumpWidget(build('x'));
          await tester.pumpAndSettle();

          // Assert — the same State object survived, so the subtree was not
          // re-parented, and the scroll position and focus were preserved.
          expect(
            tester.state<_ScrollableFormState>(find.byType(_ScrollableForm)),
            same(stateBefore),
          );
          expect(focusNode.hasFocus, isTrue);
          expect(controller.offset, 200);

          // Act — toggle back to no message.
          await tester.pumpWidget(build(null));
          await tester.pumpAndSettle();

          // Assert — still the original State object.
          expect(
            tester.state<_ScrollableFormState>(find.byType(_ScrollableForm)),
            same(stateBefore),
          );
          expect(focusNode.hasFocus, isTrue);
          expect(controller.offset, 200);
        },
      );

      testWidgets(
        'should keep the announced semantics identical when the message is set '
        'and publish nothing when it is cleared',
        (WidgetTester tester) async {
          // Arrange
          final handle = tester.ensureSemantics();
          Widget build(String? message) => _app(
            LiveAnnouncer(message: message, child: const Text('Results')),
          );

          await tester.pumpWidget(build(null));
          await tester.pumpAndSettle();

          // Assert — no live region, and only the child's own label: the
          // announcer adds nothing while there is no message.
          final cleared = tester.getSemantics(find.byType(LiveAnnouncer));
          expect(cleared.flagsCollection.isLiveRegion, isFalse);
          expect(cleared.label, 'Results');

          // Act
          await tester.pumpWidget(build('Five results found'));
          await tester.pumpAndSettle();

          // Assert — a live region carrying the message.
          final announced = tester.getSemantics(find.byType(LiveAnnouncer));
          expect(announced.flagsCollection.isLiveRegion, isTrue);
          expect(announced.label, contains('Five results found'));

          // Act — clear it again.
          await tester.pumpWidget(build(null));
          await tester.pumpAndSettle();

          // Assert — back to nothing announced.
          final reCleared = tester.getSemantics(find.byType(LiveAnnouncer));
          expect(reCleared.flagsCollection.isLiveRegion, isFalse);
          expect(reCleared.label, 'Results');
          handle.dispose();
        },
      );
    });
  });
}
