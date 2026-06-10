import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helper/iso_language.dart';

/// Displays a compact chip for a language, optionally with a total count.
///
/// The chip pairs an ISO language code with either its matching emoji flag or a
/// generic info icon for the special `total` bucket. This makes it suitable for
/// filters, summaries, and analytics UIs where language metadata needs to stay
/// glanceable.
///
/// [language] is the ISO-639-1 language code used to retrieve a matching flag.
/// [total] is the related number for the language, such as a contact count.
///
/// ```dart
/// FlagChip(
///   language: language,
///   total: 100,
/// );
/// ```
class FlagChip extends StatelessWidget {
  /// Creates a [FlagChip] for the given [language].
  ///
  /// Supplying [onDeleted] lets the chip participate in removable filter UIs,
  /// while omitting [total] keeps the label compact for dense layouts.
  const FlagChip({
    super.key,
    required this.language,
    this.total,
    this.onDeleted,
  });

  /// Stores the ISO-639-1 code or special summary label shown by the chip.
  final String language;

  /// Supplies an optional numeric total displayed beside the language code.
  final int? total;

  /// Runs when the chip's delete affordance is activated.
  final VoidCallback? onDeleted;

  /// Builds the chip with a localized number format and flag-style avatar.
  ///
  /// The count uses [NumberFormat.decimalPattern] so large totals remain easy to
  /// scan across locales and analytics-heavy interfaces.
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
      items.add(
        Text(
          formatDecimal.format(total),
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
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
