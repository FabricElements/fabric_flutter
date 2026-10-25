import 'dart:io';
import 'dart:ui' show Tristate;

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
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Collects the child [SemanticsNode]s of [node] in tree order.
List<SemanticsNode> _childrenOf(SemanticsNode node) {
  final children = <SemanticsNode>[];
  node.visitChildren((child) {
    children.add(child);
    return true;
  });
  return children;
}

/// Verifies that a single `automationKey` drives one identity across the
/// semantics identifier, the test finder, and the agent element index.
///
/// Every widget under test must expose the key to `find.bySemanticsIdentifier`
/// (and therefore the web `flt-semantics-identifier` DOM attribute) at the
/// same time it registers the same id in `AgentElementIndex`. The identifier
/// is applied by `AgentElement` alone — no component sets `identifier:`
/// directly — so the agent id, the semantics identifier, the test finder, and
/// the web DOM attribute are one value.
void main() {
  final index = AgentElementIndex.instance;

  setUp(index.reset);
  tearDown(index.reset);

  /// Pumps [child] and asserts that [key] resolves to exactly one semantics
  /// node (via the finder) and one indexed agent element. Returns the
  /// resolved [SemanticsNode] so callers can assert its shape.
  Future<SemanticsNode> expectOneIdentity(
    WidgetTester tester,
    String key,
    Widget child,
  ) async {
    // Arrange
    final handle = tester.ensureSemantics();

    // Act
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

    // Assert — semantics finder resolves the key to exactly one node.
    final finder = find.bySemanticsIdentifier(key);
    expect(finder, findsOneWidget);

    // Assert — the agent index lists the same key.
    expect(index.contains(key), isTrue);
    expect(index.handle(key)?.id, key);

    handle.dispose();
    return tester.getSemantics(finder);
  }

  group('one key = one identity', () {
    testWidgets('card_button', (tester) async {
      final node = await expectOneIdentity(
        tester,
        'home_grid_button_orders',
        CardButton(
          image: 'https://example.com/a.jpg',
          headline: 'Open orders',
          onPressed: () {},
          automationKey: 'home_grid_button_orders',
        ),
      );
      final data = node.getSemanticsData();
      expect(data.label, 'Open orders');
      expect(data.flagsCollection.isButton, isTrue);
      expect(node.childrenCount, 0);
    });

    testWidgets('smart_button', (tester) async {
      final node = await expectOneIdentity(
        tester,
        'home_toolbar_button_save',
        SmartButton(
          button: ButtonOptions(label: 'Save Profile', path: '/save'),
          automationKey: 'home_toolbar_button_save',
        ),
      );
      final data = node.getSemanticsData();
      expect(data.label, 'Save Profile');
      expect(node.childrenCount, 1);
      // The button role lives on the child node, as it did before this change.
      expect(
        _childrenOf(node).single.getSemanticsData().flagsCollection.isButton,
        isTrue,
      );
    });

    testWidgets('expressive_button_group', (tester) async {
      final node = await expectOneIdentity(
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
      final data = node.getSemanticsData();
      expect(data.label, 'All');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.childrenCount, 0);
    });

    testWidgets('expressive_fab', (tester) async {
      final node = await expectOneIdentity(
        tester,
        'messages_fab_compose',
        const ExpressiveFab(
          icon: Icons.add,
          semanticsLabel: 'Compose',
          automationKey: 'messages_fab_compose',
        ),
      );
      final data = node.getSemanticsData();
      expect(data.label, 'Compose');
      expect(data.flagsCollection.isButton, isTrue);
      expect(node.childrenCount, 0);
    });

    testWidgets('google_maps_search', (tester) async {
      final node = await expectOneIdentity(
        tester,
        'places_form_input_search',
        const GoogleMapsSearch(
          apiKey: 'test',
          automationKey: 'places_form_input_search',
        ),
      );
      final data = node.getSemanticsData();
      expect(data.label, 'label--search-by-label');
      expect(data.flagsCollection.isTextField, isTrue);
      expect(node.childrenCount, 1);
    });

    testWidgets('input_data', (tester) async {
      final node = await expectOneIdentity(
        tester,
        'settings_profile_input_email',
        InputData(
          value: '',
          label: 'Email',
          type: InputDataType.text,
          automationKey: 'settings_profile_input_email',
        ),
      );
      final data = node.getSemanticsData();
      expect(data.label, 'Email');
      expect(node.childrenCount, 1);
      expect(
        _childrenOf(node).single.getSemanticsData().flagsCollection.isTextField,
        isTrue,
      );
    });

    testWidgets('popup_entry', (tester) async {
      final node = await expectOneIdentity(
        tester,
        'accounts_menu_entry_payments',
        const PopupEntry(
          semanticsLabel: 'Payments',
          automationKey: 'accounts_menu_entry_payments',
          child: Text('entry'),
        ),
      );
      final data = node.getSemanticsData();
      expect(data.label, 'Payments');
      expect(node.childrenCount, 1);
    });

    testWidgets('screen_context', (tester) async {
      final node = await expectOneIdentity(
        tester,
        'screen_dashboard',
        const ScreenContext(routeName: 'dashboard', child: SizedBox()),
      );
      expect(node.getSemanticsData().identifier, 'screen_dashboard');
      expect(node.childrenCount, 0);
    });

    testWidgets('smart_image', (tester) async {
      final node = await expectOneIdentity(
        tester,
        'home_header_image_logo',
        const SmartImage(url: null, automationKey: 'home_header_image_logo'),
      );
      final data = node.getSemanticsData();
      expect(data.label, contains('label--image'));
      expect(data.flagsCollection.isImage, isTrue);
    });

    testWidgets('user_avatar', (tester) async {
      final node = await expectOneIdentity(
        tester,
        'profile_header_image_avatar',
        const UserAvatar(
          avatar: null,
          name: 'Ada Lovelace',
          automationKey: 'profile_header_image_avatar',
        ),
      );
      final data = node.getSemanticsData();
      expect(data.label, 'Ada Lovelace');
      // Single node: the pre-existing duplicate identifier node is gone.
      expect(node.childrenCount, 0);
    });

    testWidgets('adaptive_navigation_scaffold', (tester) async {
      final node = await expectOneIdentity(
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
      expect(node.getSemanticsData().identifier, 'app_shell_navigation_main');
      expect(node.childrenCount, 1);
    });
  });

  group('single source of the identifier', () {
    test('only AgentElement applies Semantics.identifier', () {
      // Arrange
      final componentDir = Directory('lib/component');
      final files = componentDir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.dart'),
      );

      // Assert — no component sets `identifier:` directly anymore.
      for (final file in files) {
        expect(
          file.readAsStringSync().contains('identifier:'),
          isFalse,
          reason:
              '${file.path} should not set Semantics.identifier directly; '
              'AgentElement is the single source',
        );
      }

      // Assert — the one place that does set it is the AgentElement fold.
      final binding = File('lib/helper/agent/agent_element_binding.dart')
          .readAsStringSync();
      expect(binding.contains('identifier: id'), isTrue);
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
