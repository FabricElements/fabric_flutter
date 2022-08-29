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
    this.color = Colors.black,
    this.colorText = Colors.white,
  }) : super(key: key);
  final String language;
  final int? total;
  final Color color;
  final Color colorText;

  @override
  Widget build(BuildContext context) {
    final NumberFormat formatDecimal = NumberFormat.decimalPattern();
    final theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    List<Widget> items = [];
    if (language == 'total') {
      items.add(Container(width: 16));
    }
    if (language != 'total') {
      items.add(
        SizedBox(
          height: 30,
          width: 50,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              ISOLanguages.getEmoji(language) ?? '',
              style: textTheme.bodyText2!.copyWith(
                fontSize: 20,
                color: colorText,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    items.add(
      SizedBox(
        height: 30,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, right: 8, bottom: 8),
          child: Text(
            language.toUpperCase(),
            style: textTheme.bodyText2!.copyWith(
              color: colorText,
            ),
          ),
        ),
      ),
    );
    if (total != null) {
      items.add(
        Container(
          color: theme.primaryColor,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              formatDecimal.format(total),
              style: textTheme.bodyText2!.copyWith(color: colorText),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
        child: Material(
          color: color,
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 0,
          child: Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              direction: Axis.horizontal,
              children: items,
            ),
          ),
        ),
      ),
    );
  }
}
