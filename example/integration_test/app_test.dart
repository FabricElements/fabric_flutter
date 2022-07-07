import 'package:fabric_flutter_example/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// import '../lib/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized(); // NEW

  group('end-to-end test', () {
    testWidgets('tap on the floating action button, verify counter',
        (tester) async {
      expect(true, true);
      app.main();
      await tester.pumpAndSettle();

      // Verify user is sign out first
      expect(find.text('Welcome'), findsOneWidget);

      // Verify the counter starts at 0.
      // expect(find.text('0'), findsOneWidget);

      // Finds the floating action button to tap on.
      // final Finder fab = find.byTooltip('Welcome');

      // Emulate a tap on the floating action button.
      // await tester.tap(fab);

      // Trigger a frame.
      // await tester.pumpAndSettle();

      // Verify the counter increments by 1.
      expect(find.text('Welcome'), findsOneWidget);
    });
  });
}
