import 'package:flutter/material.dart';

/// SectionTitle is a widget used for emphasis and a screen which can show the start of a section.
///
/// [description] Description for the section, displayed in the widget.
/// [headline] Headline for the section, emphasis text.
/// SectionTitle(
///   headline: 'This is the headline, emphasised text.',
///   description: 'This is where the description will go.',
/// );
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    this.description,
    required this.headline,
    this.headlineStyle,
    this.descriptionStyle,
  });

  final String? description;
  final String headline;
  final TextStyle? headlineStyle;
  final TextStyle? descriptionStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    TextStyle? defaultHeadlineStyle = headlineStyle ?? textTheme.headlineMedium;
    TextStyle? defaultDescriptionStyle =
        descriptionStyle ?? textTheme.bodyMedium;

    RegExp regExp = RegExp(
      r'{.*?}',
      multiLine: true,
    );
    List<TextSpan> importantData(String textConvert, TextStyle? textStyle) {
      List<TextSpan> text = [];
      String textFinal = textConvert;
      int? initialHelper = 0;
      Iterable matches = regExp.allMatches(textFinal);
      if (matches.isNotEmpty) {
        for (var match in matches) {
          if (match.start > initialHelper) {
            text.add(
              TextSpan(
                text: (textFinal.substring(initialHelper!, match.start))
                    .replaceAll('_', ' ')
                    .replaceAll('{', '')
                    .replaceAll('}', ''),
                style: textStyle,
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
              style: textStyle?.copyWith(
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
            style: textStyle,
          ),
        );
      } else {
        text.add(TextSpan(
          text: textFinal,
          style: textStyle,
        ));
      }
      return text;
    }

    List<Widget> items = [
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text.rich(
          TextSpan(
            children: importantData(headline, defaultHeadlineStyle),
          ),
        ),
      ),
    ];
    if (description != null) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(
          TextSpan(
            children: importantData(description!, defaultDescriptionStyle),
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
