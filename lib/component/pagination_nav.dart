import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import 'input_data.dart';

/// Renders pagination controls for moving through discrete result pages.
///
/// The widget keeps transient loading state locally so repeated taps cannot trigger
/// overlapping navigation requests. It also exposes a page-size selector to keep list
/// navigation and page limit changes visually grouped in one reusable control bar.
class PaginationNav extends StatefulWidget {
  /// Creates a pagination toolbar with previous, next, and optional edge navigation.
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

  /// Reports the currently visible page number.
  final int page;
  /// Reports the currently selected number of items per page.
  final int limit;
  /// Indicates whether advancing to the next page is currently allowed.
  final bool canPaginate;
  /// Loads the next page when the user activates the forward action.
  final Function next;
  /// Loads the previous page when the user activates the back action.
  final Function previous;
  /// Optionally jumps directly to the first page in the result set.
  final Function? first;
  /// Optionally jumps directly to the final page in the result set.
  final Function? last;
  /// Receives a newly selected page size when the limit dropdown changes.
  final ValueChanged<int> limitChange;
  /// Defines the first logical page so edge-button disabling works with custom indices.
  final int initialPage;
  /// Reports the total number of pages available for the current dataset.
  final int totalPages;
  /// Lists the page-size options offered by the limit dropdown.
  final List<int> limits;
  /// Appends extra widgets into the toolbar for context-specific actions or filters.
  final List<Widget> children;

  /// Creates the state that throttles pagination actions during async transitions.
  @override
  State<PaginationNav> createState() => _PaginationNavState();
}

/// Tracks temporary loading state while pagination callbacks are running.
class _PaginationNavState extends State<PaginationNav> {
  /// Prevents repeated taps from firing overlapping pagination requests.
  bool loading = false;

  /// Builds a responsive toolbar that adapts between row and wrap layouts.
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
