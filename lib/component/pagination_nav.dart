import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import 'input_data.dart';

class PaginationNav extends StatelessWidget {
  const PaginationNav({
    Key? key,
    required this.page,
    required this.canPaginate,
    required this.next,
    required this.previous,
    this.initialPage = 1,
    required this.totalPages,
    required this.limit,
    required this.limitChange,
    this.limits = const [5, 10, 20, 50],
  }) : super(key: key);
  final int page;
  final int limit;
  final bool canPaginate;
  final Function next;
  final Function previous;
  final ValueChanged<int> limitChange;
  final int initialPage;
  final int totalPages;
  final List<int> limits;

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context)!;
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
    List<Widget> actions = [
      Text('Page: $page / $totalPages'),
      const SizedBox(width: 16),
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
      const Spacer(),
      TextButton.icon(
        onPressed: page > initialPage ? () => previous() : null,
        icon: const Icon(Icons.arrow_back),
        label: Text(locales.get('label--previous').toUpperCase()),
      ),
      const SizedBox(width: 16),
      OutlinedButton.icon(
        onPressed: canPaginate ? () => next() : null,
        icon: const Icon(Icons.arrow_forward),
        label: Text(locales.get('label--next').toUpperCase()),
      ),
    ];
    return Row(
      children: actions,
    );
  }
}
