import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import 'input_data.dart';

/// Defines the pagination component with controls
class PaginationNav extends StatefulWidget {
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

  final int page;
  final int limit;
  final bool canPaginate;
  final Function next;
  final Function previous;
  final Function? first;
  final Function? last;
  final ValueChanged<int> limitChange;
  final int initialPage;
  final int totalPages;
  final List<int> limits;
  final List<Widget> children;

  @override
  State<PaginationNav> createState() => _PaginationNavState();
}

class _PaginationNavState extends State<PaginationNav> {
  bool loading = false;

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
