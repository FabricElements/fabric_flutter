import 'package:fabric_flutter/component/adaptive_navigation_scaffold.dart';
import 'package:fabric_flutter/component/card_button.dart';
import 'package:fabric_flutter/component/expressive_button_group.dart';
import 'package:fabric_flutter/component/expressive_fab.dart';
import 'package:fabric_flutter/component/google_maps_search.dart';
import 'package:fabric_flutter/component/input_data.dart';
import 'package:fabric_flutter/component/popup_entry.dart';
import 'package:fabric_flutter/component/screen_context.dart';
import 'package:fabric_flutter/component/smart_button.dart';
import 'package:fabric_flutter/component/smart_image.dart';
import 'package:fabric_flutter/component/user_avatar.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies that a single `automationKey` drives one identity across the
/// semantics identifier, the test finder, and the agent element index.
///
/// Every widget under test must expose the key to `find.bySemanticsIdentifier`
/// (and therefore the web `flt-semantics-identifier` DOM attribute) at the
/// same time it registers the same id in `AgentElementIndex`.
void main() {
  final index = AgentElementIndex.instance;

  setUp(index.reset);
  tearDown(index.reset);

  /// Pumps [child] and asserts that [key] resolves to exactly one semantics
  /// node (via the finder) and one indexed agent element.
  Future<void> expectOneIdentity(
    WidgetTester tester,
    String key,
    Widget child,
  ) async {
    // Arrange
    final handle = tester.ensureSemantics();

    // Act
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

    // Assert — semantics finder resolves the key to a node.
    expect(find.bySemanticsIdentifier(key), findsOneWidget);

    // Assert — the agent index lists the same key.
    expect(index.contains(key), isTrue);
    expect(index.handle(key)?.id, key);

    handle.dispose();
  }

  group('one key = one identity', () {
    testWidgets('card_button', (tester) async {
      await expectOneIdentity(
        tester,
        'home_grid_button_orders',
        CardButton(
          image: 'https://example.com/a.jpg',
          headline: 'Open orders',
          onPressed: () {},
          automationKey: 'home_grid_button_orders',
        ),
      );
    });

    testWidgets('smart_button', (tester) async {
      await expectOneIdentity(
        tester,
        'home_toolbar_button_save',
        SmartButton(
          button: ButtonOptions(label: 'Save Profile', path: '/save'),
          automationKey: 'home_toolbar_button_save',
        ),
      );
    });

    testWidgets('expressive_button_group', (tester) async {
      await expectOneIdentity(
        tester,
        'filter_bar_segment_all',
        ExpressiveButtonGroup<String>(
          items: const [
            ExpressiveButtonItem(
              value: 'all',
              label: 'All',
              automationKey: 'filter_bar_segment_all',
            ),
          ],
          selected: 'all',
        ),
      );
    });

    testWidgets('expressive_fab', (tester) async {
      await expectOneIdentity(
        tester,
        'messages_fab_compose',
        const ExpressiveFab(
          icon: Icons.add,
          semanticsLabel: 'Compose',
          automationKey: 'messages_fab_compose',
        ),
      );
    });

    testWidgets('google_maps_search', (tester) async {
      await expectOneIdentity(
        tester,
        'places_form_input_search',
        const GoogleMapsSearch(
          apiKey: 'test',
          automationKey: 'places_form_input_search',
        ),
      );
    });

    testWidgets('input_data', (tester) async {
      await expectOneIdentity(
        tester,
        'settings_profile_input_email',
        InputData(
          value: '',
          label: 'Email',
          type: InputDataType.text,
          automationKey: 'settings_profile_input_email',
        ),
      );
    });

    testWidgets('popup_entry', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PopupEntry(
              semanticsLabel: 'Payments',
              automationKey: 'accounts_menu_entry_payments',
              child: Text('entry'),
            ),
          ),
        ),
      );
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsIdentifier('accounts_menu_entry_payments'),
        findsOneWidget,
      );
      expect(index.contains('accounts_menu_entry_payments'), isTrue);
      handle.dispose();
    });

    testWidgets('screen_context', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScreenContext(routeName: 'dashboard', child: SizedBox()),
        ),
      );
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsIdentifier('screen_dashboard'), findsOneWidget);
      expect(index.contains('screen_dashboard'), isTrue);
      handle.dispose();
    });

    testWidgets('smart_image', (tester) async {
      await expectOneIdentity(
        tester,
        'home_header_image_logo',
        const SmartImage(url: null, automationKey: 'home_header_image_logo'),
      );
    });

    testWidgets('user_avatar', (tester) async {
      await expectOneIdentity(
        tester,
        'profile_header_image_avatar',
        const UserAvatar(
          avatar: null,
          name: 'Ada Lovelace',
          automationKey: 'profile_header_image_avatar',
        ),
      );
    });

    testWidgets('adaptive_navigation_scaffold', (tester) async {
      await expectOneIdentity(
        tester,
        'app_shell_navigation_main',
        AdaptiveNavigationScaffold(
          destinations: const [
            AdaptiveDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
            AdaptiveDestination(
              icon: Icon(Icons.inbox_outlined),
              label: 'Inbox',
            ),
          ],
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          automationKey: 'app_shell_navigation_main',
          body: const SizedBox.expand(),
        ),
      );
    });
  });

  group('null/empty automationKey registers nothing', () {
    testWidgets('unkeyed components contribute no index entry', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(
                  width: 200,
                  height: 200,
                  child: SmartImage(url: null),
                ),
                const UserAvatar(avatar: null, name: 'Ada'),
                const ExpressiveFab(icon: Icons.add, semanticsLabel: 'Compose'),
              ],
            ),
          ),
        ),
      );

      // Assert — only keyed widgets register; these unkeyed ones add nothing.
      expect(index.ids, isEmpty);
    });
  });
}
