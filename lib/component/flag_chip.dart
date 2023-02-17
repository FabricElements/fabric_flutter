import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helper/iso_language.dart';

/// FlagChip is used to represent the language as a flag along with a related number.
///
/// [language] ISO-639-1 language code used to retrieve a flag corresponding to the language.
/// [total] The related number to the language, such as number of contacts related to the language.
/// ```dart
/// FlagChip(
///   language: language,
///   total: 100,
///   color: Colors.indigo.shade500,
///   colorText: Colors.white,
/// );
/// ```
class FlagChip extends StatelessWidget {
  const FlagChip({
    Key? key,
    required this.language,
    this.total,
    this.onDeleted,
  }) : super(key: key);
  final String language;
  final int? total;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final NumberFormat formatDecimal = NumberFormat.decimalPattern();
    final theme = Theme.of(context);
    List<Widget> items = [];
    late Widget icon;

    if (language == 'total') {
      icon = const Icon(Icons.info);
    } else {
      icon = Text(ISOLanguages.getEmoji(language) ?? '');
    }
    items.add(
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(language.toUpperCase()),
      ),
    );
    if (total != null) {
      items.add(Text(
        formatDecimal.format(total),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ));
    }

    return Chip(
      avatar: icon,
      label: Flex(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        direction: Axis.horizontal,
        children: items,
      ),
      onDeleted: onDeleted,
    );
  }
}
