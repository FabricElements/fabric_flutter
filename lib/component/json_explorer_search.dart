import 'dart:convert';

import 'package:fabric_flutter/component/input_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:json_explorer/json_explorer.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../helper/app_localizations_delegate.dart';
import '../state/state_alert.dart';

/// This widget is used to display a JSON object in a searchable and
/// interactive way.
/// It uses the [json_explorer](https://pub.dev/packages/json_explorer)
/// package to display the JSON object in a tree-like structure.
/// It also provides a search input to filter the JSON object
/// and highlight the search results.
/// It also provides buttons to expand/collapse all nodes
/// and copy the JSON object to the clipboard.
class JsonExplorerSearch extends StatefulWidget {
  final Map<dynamic, dynamic>? json;

  const JsonExplorerSearch({
    super.key,
    required this.json,
  });

  @override
  State<JsonExplorerSearch> createState() => _JsonExplorerSearchState();
}

class _JsonExplorerSearchState extends State<JsonExplorerSearch> {
  final itemScrollController = ItemScrollController();
  final JsonExplorerStore store = JsonExplorerStore();

  @override
  void initState() {
    store.buildNodes(widget.json, areAllCollapsed: true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final locales = AppLocalizations.of(context);
    final alert = Provider.of<StateAlert>(context, listen: false);

    /// Theme definitions of the json explorer
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
      highlightColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.3,
      ),
    );

    void copyText(dynamic text) {
      if (text == null || text.toString().isEmpty) return;
      Clipboard.setData(ClipboardData(text: text.toString()));
      // if text is medium size to low size, show a snackbar
      String message = locales.get('alert--copy-clipboard');
      if (text.toString().length <= 100) {
        message += ': $text';
      }
      alert.show(AlertData(
        body: message,
        duration: 1,
        clear: true,
      ));
    }

    return ChangeNotifierProvider.value(
      value: store,
      child: Consumer<JsonExplorerStore>(
        builder: (context, state, child) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
              child: Row(
                children: [
                  // Search input
                  Expanded(
                    child: InputData(
                      value: state.searchTerm,
                      type: InputDataType.text,
                      onChanged: (value) async {
                        state.search(value ?? '');
                        // If the search term is not empty, focus on the first search result
                        if (!state.areAllExpanded()) state.expandAll();
                      },
                      prefixIcon: const Icon(Icons.search),
                      hintText: locales.get('label--search'),
                      suffixIcon: state.searchTerm.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                state.search('');
                              },
                              icon: const Icon(Icons.close),
                              tooltip: locales.get('label--clear'),
                            )
                          : null,
                    ),
                  ),
                  if (state.searchResults.isNotEmpty) ...[
                    // Search result count
                    Gap(8),
                    Text(_searchFocusText()),
                    // Previous search result button
                    Gap(16),
                    IconButton(
                      onPressed: state.focusedSearchResultIndex > 0
                          ? () {
                              store.focusPreviousSearchResult();
                              _scrollToSearchMatch();
                            }
                          : null,
                      icon: const Icon(Icons.arrow_drop_up),
                      tooltip: locales.get('label--previous'),
                      color: theme.colorScheme.primary,
                    ),
                    // Next search result button
                    Gap(16),
                    IconButton(
                      onPressed: state.focusedSearchResultIndex <
                              state.searchResults.length - 1
                          ? () {
                              store.focusNextSearchResult();
                              _scrollToSearchMatch();
                            }
                          : null,
                      icon: const Icon(Icons.arrow_drop_down),
                      tooltip: locales.get('label--next'),
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
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
            ),
            Expanded(
              child: Container(
                color: theme.colorScheme.surfaceContainer,
                padding: const EdgeInsets.all(16),
                child: JsonExplorer(
                  nodes: state.displayNodes,
                  itemScrollController: itemScrollController,
                  itemSpacing: 8,
                  maxRootNodeWidth: 300,

                  /// Builds a widget after each root node displaying the
                  /// number of children nodes that it has. Displays `{x}`
                  /// if it is a class or `[x]` in case of arrays.
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
                        style: textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ),

                  /// Build an animated collapse/expand indicator. Implicitly
                  /// animates the indicator when
                  /// [NodeViewModelState.isCollapsed] changes.
                  collapsableToggleBuilder: (context, node) => AnimatedRotation(
                    turns: node.isCollapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(Icons.arrow_drop_down),
                  ),

                  /// Builds a trailing widget that copies the node key: value
                  ///
                  /// Uses [NodeViewModelState.isFocused] to display the
                  /// widget only in focused widgets.
                  trailingBuilder: (context, node) => node.isFocused
                      ? IconButton(
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
                            // Get object to copy based on the finalKey path. Convert . to a Map or List
                            // from key to a path.
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
                            // Do not copy if the object is null
                            if (objectToCopy == null) return;
                            // Copy the object to clipboard
                            copyText(jsonEncode(objectToCopy));
                          },
                        )
                      : const Gap(32),

                  /// Creates a custom format for classes and array names.
                  rootNameFormatter: (dynamic name) => '$name',

                  /// Dynamically changes the property value style and
                  /// interaction when an URL is detected.
                  valueStyleBuilder: (dynamic value, style) {
                    final isUrl = _valueIsUrl(value);
                    return PropertyOverrides(
                      style: isUrl
                          ? style.copyWith(
                              decoration: TextDecoration.underline,
                            )
                          : style,
                      onTap: isUrl ? () => _launchUrl(value as String) : null,
                    );
                  },
                  theme: jsonExplorerTheme,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _searchFocusText() =>
      '${store.focusedSearchResultIndex + 1} of ${store.searchResults.length}';

  void _scrollToSearchMatch() {
    final index = store.displayNodes.indexOf(store.focusedSearchResult.node);
    if (index != -1) {
      itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  bool _valueIsUrl(dynamic value) {
    if (value is String) {
      return Uri.tryParse(value)?.hasAbsolutePath ?? false;
    }
    return false;
  }

  Future _launchUrl(String url) {
    return launchUrlString(url);
  }
}
