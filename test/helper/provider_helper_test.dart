import 'package:fabric_flutter/helper/provider_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Minimal notifier used to register a provider inside the test tree.
class _Counter extends ChangeNotifier {
  /// Stores the current count.
  int value = 0;
}

/// A type that is never registered, used to assert the negative case.
class _Missing {}

void main() {
  group('ProviderHelper.isProviderDefined', () {
    testWidgets('should return true when the provider is registered', (
      tester,
    ) async {
      // Arrange
      bool? result;
      await tester.pumpWidget(
        ChangeNotifierProvider<_Counter>(
          create: (_) => _Counter(),
          child: Builder(
            builder: (context) {
              result = ProviderHelper.isProviderDefined<_Counter>(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Act & Assert
      expect(result, isTrue);
    });

    testWidgets('should return false when the provider is missing', (
      tester,
    ) async {
      // Arrange
      bool? result;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            result = ProviderHelper.isProviderDefined<_Missing>(context);
            return const SizedBox.shrink();
          },
        ),
      );

      // Act & Assert
      expect(result, isFalse);
    });

    test('should return false when the context is null', () {
      // Arrange & Act
      final result = ProviderHelper.isProviderDefined<_Counter>(null);

      // Assert
      expect(result, isFalse);
    });

    testWidgets('should not register the caller as a listener', (tester) async {
      // Arrange
      final counter = _Counter();
      var builds = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider<_Counter>.value(
          value: counter,
          child: Builder(
            builder: (context) {
              builds++;
              ProviderHelper.isProviderDefined<_Counter>(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final buildsAfterFirstPump = builds;

      // Act
      counter.value = 1;
      counter.notifyListeners();
      await tester.pump();

      // Assert: `listen: false` means the notification must not rebuild.
      expect(builds, buildsAfterFirstPump);
    });
  });
}
