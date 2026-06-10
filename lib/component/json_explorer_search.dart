import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:json_explorer/json_explorer.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../helper/app_localizations_delegate.dart';
import 'alert_data.dart';
import 'input_data.dart';

/// Builds a searchable explorer for JSON-like data.
///
/// [json] stays nullable so parents can render the widget before data loads and
/// still show a predictable empty state, while [empty] lets callers replace the
/// default placeholder with context-specific guidance.
class JsonExplorerSearch extends StatefulWidget {
  /// Stores the JSON-like payload that the explorer renders.
  ///
  /// Keeping [json] nullable lets the widget treat `null` the same as an empty
  /// payload, which avoids forcing callers to build placeholder maps.
  final Map<dynamic, dynamic>? json;

  /// Stores the widget shown when [json] has no visible content.
  ///
  /// Allowing a custom [Widget] helps hosts align the empty state with the rest
  /// of their screen instead of always using the built-in informational tile.
  final Widget? empty;

  /// Creates a searchable explorer for structured JSON data.
  ///
  /// Requiring [json] keeps the caller explicit about the data source even when
  /// the payload is `null`, which makes loading and empty scenarios easier to
  /// reason about.
  const JsonExplorerSearch({super.key, required this.json, this.empty});

  /// Creates the mutable state that coordinates search and expansion behavior.
  ///
  /// A dedicated [State] object keeps transient explorer interactions out of the
  /// widget configuration so parents can rebuild freely without losing control
  /// logic.
  @override
  State<JsonExplorerSearch> createState() => _JsonExplorerSearchState();
}

/// Coordinates search, scrolling, expansion, and copy actions.
///
/// Keeping this logic in [_JsonExplorerSearchState] lets the widget react to
/// changing JSON payloads while preserving the controller objects that power
/// focused navigation inside the explorer.
class _JsonExplorerSearchState extends State<JsonExplorerSearch> {
  /// Stores the controller that scrolls focused matches into view.
  ///
  /// Reusing a single [ItemScrollController] keeps search navigation smooth and
  /// avoids recreating scroll state every time [build] runs.
  final itemScrollController = ItemScrollController();

  /// Stores the explorer state shared with the rendered tree.
  ///
  /// Holding one [JsonExplorerStore] instance lets search results, focus state,
  /// and expansion state stay synchronized across UI interactions.
  final JsonExplorerStore store = JsonExplorerStore();

  /// Stores whether the current payload should render the empty state.
  ///
  /// Caching this value keeps the empty-state decision easy to reuse across
  /// lifecycle methods without repeating null and emptiness checks in the UI.
  bool isEmpty = false;

  /// Initializes the explorer from the first [JsonExplorerSearch.json] value.
  ///
  /// Building the nodes during [initState] ensures the tree is ready before the
  /// first frame so the widget shows either content or the empty state without a
  /// second setup pass.
  @override
  void initState() {
    super.initState();
    isEmpty = widget.json == null || widget.json!.isEmpty;
    store.buildNodes(widget.json, areAllCollapsed: true);
  }

  /// Refreshes the explorer when the parent provides a new payload.
  ///
  /// Recomputing [isEmpty] and rebuilding the store keeps search and expansion
  /// state aligned with the latest [JsonExplorerSearch.json] instead of leaving
  /// stale nodes on screen after parent updates.
  @override
  void didUpdateWidget(covariant JsonExplorerSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    isEmpty = widget.json == null || widget.json!.isEmpty;
    if (mounted) setState(() {});
    store.buildNodes(widget.json, areAllCollapsed: true);
  }

  /// Builds the searchable explorer interface.
  ///
  /// The layout keeps search, navigation, copy actions, and the tree view in a
  /// single place so callers can inspect large JSON payloads without composing
  /// additional helper widgets around this component.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final locales = AppLocalizations.of(context);

    final widgetEmpty = widget.empty ??
        ListTile(
          contentPadding: EdgeInsets.all(16),
          leading: Icon(Icons.info),
          title: Text(locales.get('label--nothing-here-yet')),
        );

    /// Returns the empty-state widget when [json] is `null` or empty.
    if (isEmpty) {
      return widgetEmpty;
    }

    /// Stores the theme overrides used by [JsonExplorer].
    final jsonExplorerTheme = JsonExplorerTheme().copyWith(
      rootKeyTextStyle: textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
      propertyKeyTextStyle: textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        fontWeight: FontWeight.bold,
      ),
      valueTextStyle: textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      keySearchHighlightTextStyle: textTheme.bodyLarge?.copyWith(
        backgroundColor: theme.colorScheme.primaryContainer,
        color: theme.colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.bold,
      ),
      valueSearchHighlightTextStyle: textTheme.bodyLarge?.copyWith(
        backgroundColor: theme.colorScheme.primaryContainer,
        color: theme.colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.bold,
      ),
      focusedKeySearchNodeHighlightTextStyle: textTheme.bodyLarge?.copyWith(
        backgroundColor: theme.colorScheme.primary,
        color: theme.colorScheme.onPrimary,
        fontWeight: FontWeight.bold,
      ),
      focusedValueSearchHighlightTextStyle: textTheme.bodyLarge?.copyWith(
        backgroundColor: theme.colorScheme.primary,
        color: theme.colorScheme.onPrimary,
        fontWeight: FontWeight.bold,
      ),
      indentationLineColor: theme.colorScheme.outline,
      indentationPadding: 8,
      propertyIndentationPaddingFactor: 4,
      highlightColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
    );

    /// Copies [text] to the clipboard and announces the result.
    ///
    /// Including a short preview for small values helps users confirm what was
    /// copied without overwhelming the snackbar for large JSON fragments.
    void copyText(dynamic text) {
      if (text == null || text.toString().isEmpty) return;
      Clipboard.setData(ClipboardData(text: text.toString()));

      /// Builds the snackbar message shown after a copy action.
      String message = locales.get('alert--copy-clipboard');
      if (text.toString().length <= 100) {
        message += ': $text';
      }
      alertData(context: context, body: message, duration: 1);
    }

    /// Provides the shared [JsonExplorerStore] to the explorer subtree.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ChangeNotifierProvider.value(
        value: store,
        child: Consumer<JsonExplorerStore>(
          builder: (context, state, child) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Row(
                children: [
                  /// Builds the search input that filters visible nodes.
                  Expanded(
                    child: InputData(
                      value: state.searchTerm,
                      type: InputDataType.text,
                      onChanged: (value) async {
                        state.search(value ?? '');
                        _scrollToSearchMatch();
                      },
                      prefixIcon: const Icon(Icons.search),
                      hintText: locales.get('label--search'),
                      suffixIcon: state.searchTerm.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                state.search('');
                              },
                              icon: const Icon(Icons.cancel),
                              tooltip: locales.get('label--clear'),
                            )
                          : null,
                      suffix: state.searchResults.isNotEmpty
                          ? Text(_searchFocusText(), style: textTheme.bodySmall)
                          : null,
                    ),
                  ),
                  if (state.searchResults.length > 1) ...[
                    /// Builds the button that focuses the previous match.
                    Gap(16),
                    IconButton(
                      onPressed: () async {
                        state.focusPreviousSearchResult(loop: true);
                        _scrollToSearchMatch();
                      },
                      icon: const Icon(Icons.arrow_drop_up),
                      tooltip: locales.get('label--previous'),
                      color: theme.colorScheme.primary,
                    ),

                    /// Builds the button that focuses the next match.
                    Gap(16),
                    IconButton(
                      onPressed: () async {
                        state.focusNextSearchResult(loop: true);
                        _scrollToSearchMatch();
                      },
                      icon: const Icon(Icons.arrow_drop_down),
                      tooltip: locales.get('label--next'),
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: state.areAllExpanded() ? null : state.expandAll,
                    label: Text(locales.get('label--expand-all')),
                    icon: const Icon(Icons.expand),
                  ),
                  const Gap(8),
                  TextButton.icon(
                    onPressed:
                        state.areAllCollapsed() ? null : state.collapseAll,
                    label: Text(locales.get('label--collapse-all')),
                    icon: const Icon(Icons.expand_less),
                  ),
                  const Gap(8),
                  TextButton.icon(
                    icon: const Icon(Icons.copy),
                    label: Text(locales.get('label--copy')),
                    onPressed: () => copyText(jsonEncode(widget.json)),
                  ),
                ],
              ),
              Expanded(
                child: Card(
                  color: theme.colorScheme.surfaceContainer,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: JsonExplorer(
                      nodes: state.displayNodes,
                      itemScrollController: itemScrollController,
                      itemSpacing: 8,
                      maxRootNodeWidth: 300,

                      /// Builds a child-count badge for each root node.
                      ///
                      /// Showing `{x}` for objects and `[x]` for arrays helps
                      /// users estimate structure size before expanding nested
                      /// content.
                      rootInformationBuilder: (context, node) => DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            node.isClass
                                ? '{${node.childrenCount}}'
                                : '[${node.childrenCount}]',
                            style: textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),

                      /// Builds the animated collapse indicator.
                      ///
                      /// Rotating the icon instead of swapping widgets keeps the
                      /// tree interaction easier to track visually as nodes open
                      /// and close.
                      collapsableToggleBuilder: (context, node) =>
                          AnimatedRotation(
                        turns: node.isCollapsed ? -0.25 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: const Icon(Icons.arrow_drop_down),
                      ),

                      /// Builds the focused-node copy action.
                      ///
                      /// Restricting this control to focused nodes reduces visual
                      /// noise while still making it easy to copy the currently
                      /// inspected branch or value.
                      trailingBuilder: (context, node) => node.isFocused
                          ? Container(
                              margin: const EdgeInsets.only(top: 4, right: 4),
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.copy),
                                constraints: BoxConstraints(
                                  minHeight: 32,
                                  minWidth: 32,
                                  maxHeight: 32,
                                  maxWidth: 32,
                                ),
                                color: theme.colorScheme.onSurface,
                                tooltip: locales.get('label--copy'),
                                onPressed: () {
                                  if (!node.isRoot) {
                                    return copyText(jsonEncode(node.value));
                                  }
                                  final key = node.key;
                                  String finalKey = key;
                                  NodeViewModelState? currentNode = node;
                                  while (currentNode != null &&
                                      currentNode.parent != null) {
                                    currentNode = currentNode.parent!;
                                    finalKey = '${currentNode.key}.$finalKey';
                                  }

                                  /// Resolves the focused key path against the
                                  /// original payload before copying.
                                  dynamic objectToCopy = widget.json;
                                  final keys = finalKey.split('.');
                                  for (final k in keys) {
                                    if (objectToCopy is Map) {
                                      objectToCopy = objectToCopy[k];
                                    } else if (objectToCopy is List) {
                                      final index = int.tryParse(k);
                                      if (index != null &&
                                          index < objectToCopy.length) {
                                        objectToCopy = objectToCopy[index];
                                      } else {
                                        objectToCopy = null;
                                        break;
                                      }
                                    } else {
                                      objectToCopy = null;
                                      break;
                                    }
                                  }

                                  /// Stops the copy action when the resolved
                                  /// object is `null`.
                                  if (objectToCopy == null) return;

                                  /// Copies the resolved object as JSON text.
                                  copyText(jsonEncode(objectToCopy));
                                },
                              ),
                            )
                          : const Gap(32),

                      /// Formats root names without altering their display text.
                      ///
                      /// Returning the raw name keeps explorer paths readable and
                      /// matches the keys used when reconstructing copy paths.
                      rootNameFormatter: (dynamic name) => '$name',

                      /// Builds value overrides for tappable URLs.
                      ///
                      /// Detecting links inline lets the explorer stay read-only
                      /// while still giving users a fast way to inspect referenced
                      /// resources.
                      valueStyleBuilder: (dynamic value, style) {
                        final isUrl = _valueIsUrl(value);
                        return PropertyOverrides(
                          style: isUrl
                              ? style.copyWith(
                                  decoration: TextDecoration.underline,
                                )
                              : style,
                          onTap:
                              isUrl ? () => _launchUrl(value as String) : null,
                        );
                      },
                      theme: jsonExplorerTheme,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the label for the focused search result position.
  ///
  /// Showing a `current/total` counter helps users understand whether another
  /// match exists before they navigate forward or backward.
  String _searchFocusText() =>
      '${store.focusedSearchResultIndex + 1}/${store.searchResults.length}';

  /// Expands search matches and scrolls the focused result into view.
  ///
  /// Expanding matched branches before scrolling prevents the list from jumping
  /// to hidden nodes, which would make keyboard-like search navigation feel
  /// unreliable.
  Future<void> _scrollToSearchMatch() async {
    /// Expands all matching branches so the focused result becomes visible.
    store.expandSearchResults();

    /// Waits for the store-driven rebuild before resolving the target index.
    await Future.delayed(const Duration(milliseconds: 300));
    final index = store.displayNodes.indexOf(store.focusedSearchResult.node);
    if (index >= 0) {
      /// Scrolls to the currently focused search result.
      itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.linear,
      );
    }
  }

  /// Determines whether [value] should behave like a tappable URL.
  ///
  /// Restricting link behavior to recognizable absolute URLs keeps plain text
  /// values from looking interactive when they are only descriptive strings.
  bool _valueIsUrl(dynamic value) {
    if (value is String) {
      return Uri.tryParse(value)?.hasAbsolutePath ?? false;
    }
    return false;
  }

  /// Launches the detected URL with the platform handler.
  ///
  /// Delegating to [launchUrlString] preserves platform-specific behavior so the
  /// widget does not need to know whether the target opens in a browser or a
  /// native app.
  Future _launchUrl(String url) {
    return launchUrlString(url);
  }
}
