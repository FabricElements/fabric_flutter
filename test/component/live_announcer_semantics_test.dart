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
  });
}
