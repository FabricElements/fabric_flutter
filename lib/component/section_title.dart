import 'package:flutter/material.dart';

/// SectionTitle is a widget used for emphasis and a screen which can show the start of a section.
///
/// [description] Description for the section, displayed in the widget.
/// [headline] Headline for the section, emphasis text.
/// SectionTitle(
///   headline: 'This is the headline, emphasised text.',
///   description: 'This is where the description will go.',
/// );
class SectionTitle extends StatefulWidget {
  const SectionTitle({
    super.key,
    this.description,
    required this.headline,
    this.condensed = false,
  });
  final String? description;
  final String headline;
  final bool condensed;

  @override
  State<SectionTitle> createState() => _SectionTitleState();
}

class _SectionTitleState extends State<SectionTitle> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    RegExp regExp = RegExp(
      r'{.*?}',
      multiLine: true,
    );
    List<TextSpan> importantData(String textConvert, String type) {
      List<TextSpan> text = [];
      String textFinal = textConvert;
      int? initialHelper = 0;
      Iterable matches = regExp.allMatches(textFinal);
      TextStyle? sizeBase = textTheme.bodyLarge;
      TextStyle? titleDefault = sizeBase;
      if (type == 'title') {
        sizeBase = textTheme.headlineMedium;
        titleDefault = sizeBase?.copyWith(
          fontWeight: FontWeight.w600,
        );
      } else {
        titleDefault = sizeBase;
        if (widget.condensed) {
          sizeBase =
              textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400);
        }
        titleDefault = titleDefault;
      }
      if (matches.isNotEmpty) {
        for (var match in matches) {
          if (match.start > initialHelper) {
            text.add(
              TextSpan(
                text: (textFinal.substring(initialHelper!, match.start))
                    .replaceAll('_', ' ')
                    .replaceAll('{', '')
                    .replaceAll('}', ''),
                style: titleDefault,
              ),
            );
            initialHelper = match.end;
          }
          text.add(
            TextSpan(
              text: (textFinal.substring(match.start, match.end))
                  .replaceAll('_', ' ')
                  .replaceAll('{', '')
                  .replaceAll('}', ''),
              style: titleDefault?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          );
          initialHelper = match.end;
        }
        text.add(
          TextSpan(
            text: (textFinal.substring(initialHelper!, textFinal.length))
                .replaceAll('_', ' ')
                .replaceAll('{', ' ')
                .replaceAll('}', ' '),
            style: titleDefault,
          ),
        );
      } else {
        text.add(TextSpan(
          text: textFinal,
          style: titleDefault,
        ));
      }
      return text;
    }

    List<Widget> items = [
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text.rich(
          TextSpan(
            children: importantData(widget.headline, 'title'),
          ),
        ),
      ),
    ];
    if (widget.description != null) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(
          TextSpan(
            children: importantData(widget.description!, 'subtitle'),
          ),
        ),
      ));
    }
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items,
        ),
      ),
    );
  }
}
