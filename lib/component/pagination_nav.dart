import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import 'input_data.dart';

/// Builds pagination controls for navigating discrete result pages.
///
/// The widget keeps transient loading state locally so the [next], [previous],
/// [first], and [last] callbacks cannot overlap. It also groups page movement,
/// page totals, and page-size selection into one reusable toolbar.
class PaginationNav extends StatefulWidget {
  /// Creates a pagination toolbar with page navigation and limit selection.
  ///
  /// The widget requires the current [page], available [totalPages], active
  /// [limit], and callbacks that update the surrounding data source. Optional
  /// [first], [last], and [children] entries extend the toolbar without
  /// changing its built-in pagination behavior.
  const PaginationNav({
    super.key,
    required this.page,
    required this.canPaginate,
    required this.next,
    required this.previous,
    this.first,
    this.last,
    this.initialPage = 1,
    required this.totalPages,
    required this.limit,
    required this.limitChange,
    this.limits = const [5, 10, 20, 50],
    this.children = const [],
  });

  /// Stores the currently visible page number.
  ///
  /// The value is shown beside the localized page label so users can confirm
  /// their current position in the result set.
  final int page;

  /// Stores the selected number of items shown per page.
  ///
  /// The value drives the dropdown state and is passed back through
  /// [limitChange] when the user selects a different option.
  final int limit;

  /// Determines whether forward navigation is currently available.
  ///
  /// The next button becomes disabled when this value is `false` or while an
  /// asynchronous pagination action is already running.
  final bool canPaginate;

  /// Provides the callback that loads the next page.
  ///
  /// The callback is awaited so the widget can keep its local loading state in
  /// sync until the navigation request completes.
  final Function next;

  /// Provides the callback that loads the previous page.
  ///
  /// The callback is awaited so repeated taps cannot trigger overlapping page
  /// changes.
  final Function previous;

  /// Provides an optional callback that jumps to the first page.
  ///
  /// The first-page button is rendered only when this callback is not `null`.
  final Function? first;

  /// Provides an optional callback that jumps to the last page.
  ///
  /// The last-page button is rendered only when this callback is not `null`.
  final Function? last;

  /// Receives a newly selected page size.
  ///
  /// The callback runs only when the dropdown value differs from the current
  /// [limit], which avoids redundant reload requests.
  final ValueChanged<int> limitChange;

  /// Defines the first logical page index.
  ///
  /// The value lets the widget support pagination schemes that do not start at
  /// `1` while still disabling backward navigation correctly.
  final int initialPage;

  /// Stores the total number of pages available.
  ///
  /// The value is displayed beside [page] and is used to disable the optional
  /// last-page action when the current page is already at the end.
  final int totalPages;

  /// Lists the page-size options available in the dropdown.
  ///
  /// Each entry is converted into a [ButtonOptions] item for the [InputData]
  /// selector.
  final List<int> limits;

  /// Stores extra widgets that appear inside the toolbar.
  ///
  /// The widgets are appended before the navigation buttons so feature-specific
  /// filters or actions can stay visually aligned with pagination controls.
  final List<Widget> children;

  /// Creates the mutable state that throttles async pagination actions.
  ///
  /// The returned [_PaginationNavState] keeps button and dropdown disabling
  /// local to this widget instead of requiring external state management.
  @override
  State<PaginationNav> createState() => _PaginationNavState();
}

/// Stores transient loading state for [PaginationNav].
///
/// The state object disables controls while awaiting pagination callbacks so a
/// single user interaction cannot issue duplicate requests.
class _PaginationNavState extends State<PaginationNav> {
  /// Tracks whether a pagination callback is currently running.
  ///
  /// The value disables navigation buttons and the limit selector until the
  /// active async operation completes.
  bool loading = false;

  /// Builds the pagination toolbar for the current [BuildContext].
  ///
  /// The layout switches between a horizontal [Row] and a wrapping [Wrap]
  /// based on the available width so the control remains usable on narrower
  /// screens.
  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final limitOptions = List.generate(widget.limits.length, (index) {
      final item = widget.limits[index];
      return ButtonOptions(label: item.toString(), value: item);
    });
    int defaultLimit = 10;
    if (limitOptions
        .where((element) => element.value == widget.limit)
        .isNotEmpty) {
      defaultLimit = widget.limit;
    }
    final pageStyle = textTheme.bodyMedium;
    const space = SizedBox(width: 16, height: 16);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double width = constraints.maxWidth;
        bool mobileBreakpoint = width >= 800;
        List<Widget> actions = [
          Text(
            '${locales.get('label--page')}: ${widget.page}',
            style: pageStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text('/ ${widget.totalPages}', style: pageStyle),
          space,
          SizedBox(
            width: 152,
            child: InputData(
              isDense: true,
              hintText: locales.get('label--limit'),
              label: locales.get('label--limit'),
              value: defaultLimit,
              type: InputDataType.dropdown,
              options: limitOptions,
              disabled: loading,
              onChanged: (value) async {
                try {
                  loading = true;
                  if (mounted) setState(() {});

                  if (value != widget.limit && value != null) {
                    widget.limitChange(value ?? widget.limit);
                  }
                } finally {
                  loading = false;
                  if (mounted) setState(() {});
                }
              },
            ),
          ),
        ];
        if (widget.children.isNotEmpty) {
          actions.addAll([space, ...widget.children]);
        }
        if (mobileBreakpoint) {
          actions.add(const Spacer());
        } else {
          actions.add(space);
        }
        if (widget.first != null) {
          actions.addAll([
            TextButton.icon(
              onPressed: widget.page > widget.initialPage && !loading
                  ? () async {
                      try {
                        loading = true;
                        if (mounted) setState(() {});

                        await widget.first!();
                      } finally {
                        loading = false;
                        if (mounted) setState(() {});
                      }
                    }
                  : null,
              icon: const Icon(Icons.first_page),
              label: Text(locales.get('label--first').toUpperCase()),
            ),
            space,
          ]);
        }
        actions.addAll([
          OutlinedButton.icon(
            onPressed: widget.page > widget.initialPage && !loading
                ? () async {
                    try {
                      loading = true;
                      if (mounted) setState(() {});

                      await widget.previous();
                    } finally {
                      loading = false;
                      if (mounted) setState(() {});
                    }
                  }
                : null,
            icon: const Icon(Icons.arrow_back),
            label: Text(locales.get('label--previous').toUpperCase()),
          ),
          space,
          OutlinedButton.icon(
            onPressed: widget.canPaginate && !loading
                ? () async {
                    try {
                      loading = true;
                      if (mounted) setState(() {});

                      await widget.next();
                    } finally {
                      loading = false;
                      if (mounted) setState(() {});
                    }
                  }
                : null,
            icon: const Icon(Icons.arrow_forward),
            label: Text(locales.get('label--next').toUpperCase()),
          ),
        ]);
        if (widget.last != null) {
          actions.addAll([
            space,
            TextButton.icon(
              onPressed: widget.page < widget.totalPages && !loading
                  ? () async {
                      try {
                        loading = true;
                        if (mounted) setState(() {});

                        await widget.last!();
                      } finally {
                        loading = false;
                        if (mounted) setState(() {});
                      }
                    }
                  : null,
              icon: const Icon(Icons.last_page),
              label: Text(locales.get('label--last').toUpperCase()),
            ),
          ]);
        }
        if (mobileBreakpoint) {
          return Container(
            constraints: BoxConstraints(minHeight: kMinInteractiveDimension),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: actions,
            ),
          );
        }
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: actions,
        );
      },
    );
  }
}
