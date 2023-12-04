import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import 'input_data.dart';

/// Defines the pagination component with controls
class PaginationNav extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final limitOptions = List.generate(limits.length, (index) {
      final item = limits[index];
      return ButtonOptions(
        label: item.toString(),
        value: item,
      );
    });
    int defaultLimit = 10;
    if (limitOptions.where((element) => element.value == limit).isNotEmpty) {
      defaultLimit = limit;
    }
    final pageStyle = textTheme.bodyMedium;
    const space = SizedBox(width: 16, height: 16);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double width = constraints.maxWidth;
        bool mobileBreakpoint = width >= 800;
        List<Widget> actions = [
          Text(
            '${locales.get('label--page')}: $page',
            style: pageStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '/ $totalPages',
            style: pageStyle,
          ),
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
              onChanged: (value) {
                if (value != limit) {
                  limitChange(value ?? limit);
                }
              },
            ),
          ),
        ];
        if (mobileBreakpoint) {
          actions.add(const Spacer());
        } else {
          actions.add(space);
        }
        if (first != null) {
          actions.addAll([
            TextButton.icon(
              onPressed: page > initialPage ? () => first!() : null,
              icon: const Icon(Icons.first_page),
              label: Text(locales.get('label--first').toUpperCase()),
            ),
            space,
          ]);
        }
        actions.addAll([
          OutlinedButton.icon(
            onPressed: page > initialPage ? () => previous() : null,
            icon: const Icon(Icons.arrow_back),
            label: Text(locales.get('label--previous').toUpperCase()),
          ),
          space,
          OutlinedButton.icon(
            onPressed: canPaginate ? () => next() : null,
            icon: const Icon(Icons.arrow_forward),
            label: Text(locales.get('label--next').toUpperCase()),
          ),
        ]);
        if (last != null) {
          actions.addAll([
            space,
            TextButton.icon(
              onPressed: page < totalPages ? () => last!() : null,
              icon: const Icon(Icons.last_page),
              label: Text(locales.get('label--last').toUpperCase()),
            ),
          ]);
        }
        if (mobileBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: actions,
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
