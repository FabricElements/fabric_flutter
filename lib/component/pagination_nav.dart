import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
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
  }) : super(key: key);
  final int page;
  final int limit;
  final bool canPaginate;
  final Function next;
  final Function previous;
  final ValueChanged<int> limitChange;
  final int initialPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context)!;
    final limitOptions = [
      ButtonOptions(
        label: '5',
        value: 5,
      ),
      ButtonOptions(
        label: '10',
        value: 10,
      ),
      ButtonOptions(
        label: '20',
        value: 20,
      ),
      ButtonOptions(
        label: '50',
        value: 50,
      ),
      ButtonOptions(
        label: '100',
        value: 100,
      ),
    ];
    List<Widget> actions = [
      Text('Page: $page / $totalPages'),
      const SizedBox(width: 16),
      SizedBox(
        width: 105,
        child: InputData(
          isDense: true,
          hintText: locales.get('label--limit'),
          label: locales.get('label--limit'),
          value: limit,
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
