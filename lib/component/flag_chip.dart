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
    final TextTheme textTheme = theme.textTheme;

    List<Widget> items = [];
    late Widget icon;

    if (language == 'total') {
      icon = const Icon(Icons.info);
    } else {
      icon = Text(
        ISOLanguages.getEmoji(language) ?? '',
        style: textTheme.bodyText2!.copyWith(
          fontSize: 20,
        ),
        textAlign: TextAlign.center,
      );
    }
    items.add(
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          language.toUpperCase(),
          style: textTheme.bodyText2,
        ),
      ),
    );
    if (total != null) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: theme.colorScheme.primaryContainer,
            clipBehavior: Clip.hardEdge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(formatDecimal.format(total)),
            ),
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

    // return Padding(
    //   padding: const EdgeInsets.symmetric(vertical: 8),
    //   child: ConstrainedBox(
    //     constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
    //     child: Material(
    //       color: color,
    //       clipBehavior: Clip.hardEdge,
    //       shape: RoundedRectangleBorder(
    //         borderRadius: BorderRadius.circular(16.0),
    //       ),
    //       elevation: 0,
    //       child: Center(
    //         widthFactor: 1.0,
    //         heightFactor: 1.0,
    //         child: Wrap(
    //           crossAxisAlignment: WrapCrossAlignment.center,
    //           direction: Axis.horizontal,
    //           children: items,
    //         ),
    //       ),
    //     ),
    //   ),
    // );
  }
}
