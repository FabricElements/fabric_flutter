import 'package:fabric_flutter/helper/announce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the announcements pushed through [SystemChannels.accessibility].
///
/// Installs a mock handler on the accessibility channel and collects the
/// `message` of every `announce` event, so tests can assert on what assistive
/// technology would actually receive instead of on widget fields.
class _AnnouncementRecorder {
  /// Collects the announced messages in the order they were sent.
  final List<String> messages = <String>[];

  /// Collects the assertiveness index of every announced message.
  ///
  /// The index is `null` when the event omitted it, which is how
  /// [Assertiveness.polite] is encoded on the wire.
  final List<int?> assertiveness = <int?>[];

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
        assertiveness.add(args?['assertiveness'] as int?);
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

/// Pumps a minimal tree and runs [onContext] with a live [BuildContext].
///
/// The tree deliberately omits `MaterialApp` so the ambient [MediaQuery] is the
/// one the framework derives from the view, unless [mediaQuery] overrides it.
Future<void> _pumpAndAnnounce(
  WidgetTester tester,
  void Function(BuildContext context) onContext, {
  MediaQueryData? mediaQuery,
}) async {
  final Widget child = Directionality(
    textDirection: TextDirection.ltr,
    child: Builder(
      builder: (BuildContext context) {
        onContext(context);
        return const SizedBox.shrink();
      },
    ),
  );
  await tester.pumpWidget(
    mediaQuery == null ? child : MediaQuery(data: mediaQuery, child: child),
  );
  await tester.pump();
}

void main() {
  group('announce', () {
    testWidgets('should announce when the platform supports announcements', (
      WidgetTester tester,
    ) async {
      // Arrange
      final recorder = _AnnouncementRecorder()..start(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(supportsAnnounce: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      // Act
      await _pumpAndAnnounce(tester, (BuildContext context) {
        announce(context, 'Saved');
      });

      // Assert
      expect(recorder.messages, <String>['Saved']);
      recorder.stop(tester);
    });

    testWidgets('should skip the announcement when unsupported', (
      WidgetTester tester,
    ) async {
      // Arrange
      final recorder = _AnnouncementRecorder()..start(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(supportsAnnounce: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      // Act
      await _pumpAndAnnounce(
        tester,
        (BuildContext context) {
          announce(context, 'Saved');
        },
        mediaQuery: const MediaQueryData(supportsAnnounce: false),
      );

      // Assert
      expect(recorder.messages, isEmpty);
      recorder.stop(tester);
    });

    testWidgets('should skip the announcement for an empty message', (
      WidgetTester tester,
    ) async {
      // Arrange
      final recorder = _AnnouncementRecorder()..start(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(supportsAnnounce: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      // Act
      await _pumpAndAnnounce(tester, (BuildContext context) {
        announce(context, '');
      });

      // Assert
      expect(recorder.messages, isEmpty);
      recorder.stop(tester);
    });

    testWidgets('should forward the requested assertiveness', (
      WidgetTester tester,
    ) async {
      // Arrange
      final recorder = _AnnouncementRecorder()..start(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(supportsAnnounce: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      // Act
      await _pumpAndAnnounce(tester, (BuildContext context) {
        announce(context, 'Urgent', assertiveness: Assertiveness.assertive);
      });

      // Assert
      expect(recorder.messages, <String>['Urgent']);
      expect(recorder.assertiveness, <int?>[Assertiveness.assertive.index]);
      recorder.stop(tester);
    });

    testWidgets('should default to a polite announcement', (
      WidgetTester tester,
    ) async {
      // Arrange
      final recorder = _AnnouncementRecorder()..start(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(supportsAnnounce: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      // Act
      await _pumpAndAnnounce(tester, (BuildContext context) {
        announce(context, 'Saved');
      });

      // Assert
      expect(recorder.assertiveness, <int?>[null]);
      recorder.stop(tester);
    });
  });
}
