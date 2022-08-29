import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';

class PaginationNav extends StatelessWidget {
  const PaginationNav({
    Key? key,
    required this.page,
    required this.canPaginate,
    required this.next,
    required this.previous,
    this.initialPage = 1,
  }) : super(key: key);
  final int page;
  final bool canPaginate;
  final Function next;
  final Function previous;
  final int initialPage;

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context)!;
    List<Widget> actions = [
      Text('Page: $page / ${canPaginate ? (1 + page) : page}'),
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
