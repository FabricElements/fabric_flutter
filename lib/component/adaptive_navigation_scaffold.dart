import 'package:flutter/material.dart';

import '../helper/agent/agent_element_binding.dart';
import '../helper/window_size.dart';
import '../serialized/agent_element_snapshot.dart';

/// A single top-level destination shown by [AdaptiveNavigationScaffold].
///
/// The same destination renders as a [NavigationDestination] in the
/// navigation bar and as a [NavigationRailDestination] in the rail.
@immutable
class AdaptiveDestination {
  /// Creates a destination with an [icon] and a visible [label].
  const AdaptiveDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.tooltip,
  });

  /// Icon shown when the destination is not selected.
  final Widget icon;

  /// Icon shown when the destination is selected; falls back to [icon].
  final Widget? selectedIcon;

  /// Visible label, also used as the accessible name of the destination.
  final String label;

  /// Optional tooltip; the navigation bar falls back to [label].
  final String? tooltip;
}

/// A [Scaffold] that switches its top-level navigation by
/// [WindowSizeClass], following the Material 3 navigation guidance:
///
/// | Size class                  | Navigation                       |
/// | --------------------------- | -------------------------------- |
/// | compact (below 600dp)       | [NavigationBar] at the bottom    |
/// | medium, expanded (600dp+)   | collapsed [NavigationRail]       |
/// | large, extraLarge (1200dp+) | extended [NavigationRail]        |
///
/// The [body] is padded horizontally with [WindowSizeClass.margin]: 16dp on
/// compact windows and 24dp from medium up. Set [applyMargin] to `false`
/// when the body manages its own margins, for example an edge-to-edge list.
///
/// The navigation region exposes [semanticsLabel], [automationKey], and
/// [semanticHint] for assistive technologies and automation agents.
class AdaptiveNavigationScaffold extends StatelessWidget {
  /// Creates an adaptive scaffold with at least two [destinations].
  const AdaptiveNavigationScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.railLeading,
    this.railTrailing,
    this.applyMargin = true,
    this.semanticsLabel,
    this.automationKey,
    this.semanticHint,
  }) : assert(destinations.length >= 2);

  /// Top-level destinations, in display order. Material 3 recommends three
  /// to five for the navigation bar.
  final List<AdaptiveDestination> destinations;

  /// Index of the selected destination in [destinations].
  final int selectedIndex;

  /// Called with the index of the destination the user selects.
  final ValueChanged<int> onDestinationSelected;

  /// Main content of the current destination.
  final Widget body;

  /// Optional app bar, shown on every size class.
  final PreferredSizeWidget? appBar;

  /// Optional floating action button. On rail layouts it is placed at the
  /// top of the rail, as Material 3 recommends.
  final Widget? floatingActionButton;

  /// Optional widget above the rail destinations, below the FAB.
  final Widget? railLeading;

  /// Optional widget below the rail destinations.
  final Widget? railTrailing;

  /// Whether to pad [body] horizontally with [WindowSizeClass.margin].
  final bool applyMargin;

  /// Accessible label for the navigation region; maps to
  /// [Semantics.label].
  final String? semanticsLabel;

  /// Deterministic automation id for the navigation region; maps to
  /// [Semantics.identifier].
  final String? automationKey;

  /// Extra guidance for screen readers and agents; maps to
  /// [Semantics.hint].
  final String? semanticHint;

  /// Wraps [navigation] in an [AgentElement] that publishes the navigation
  /// region to the agent index, with an inner [Semantics] container carrying
  /// the label, hint, and identifier.
  Widget _withSemantics(Widget navigation) {
    return AgentElement(
      id: automationKey,
      type: AgentElementType.navigation,
      label: semanticsLabel,
      hint: semanticHint,
      explicitChildNodes: true,
      child: navigation,
    );
  }

  /// Pads [body] with the window margin for [sizeClass] when enabled.
  Widget _paddedBody(WindowSizeClass sizeClass) {
    if (!applyMargin) return body;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sizeClass.margin),
      child: body,
    );
  }

  /// Builds the compact layout with a bottom [NavigationBar].
  Widget _buildBar(WindowSizeClass sizeClass) {
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: _paddedBody(sizeClass),
      bottomNavigationBar: _withSemantics(
        NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: destination.icon,
                selectedIcon: destination.selectedIcon,
                label: destination.label,
                tooltip: destination.tooltip,
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the rail layout; [extended] shows labels beside the icons.
  Widget _buildRail(
    WindowSizeClass sizeClass, {
    required bool extended,
    required Color dividerColor,
  }) {
    final leading = floatingActionButton == null && railLeading == null
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [?floatingActionButton, ?railLeading],
          );
    return Scaffold(
      appBar: appBar,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            right: false,
            child: _withSemantics(
              NavigationRail(
                extended: extended,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                leading: leading,
                trailing: railTrailing,
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: Text(destination.label),
                    ),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: dividerColor),
          Expanded(child: _paddedBody(sizeClass)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sizeClass = WindowSizeClass.of(context);
    if (!sizeClass.isAtLeast(WindowSizeClass.medium)) {
      return _buildBar(sizeClass);
    }
    return _buildRail(
      sizeClass,
      extended: sizeClass.isAtLeast(WindowSizeClass.large),
      dividerColor: colorScheme.outlineVariant,
    );
  }
}
