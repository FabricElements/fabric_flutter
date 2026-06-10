import 'package:flutter/material.dart';

/// Displays a prominent section heading with optional emphasized segments.
///
/// Curly-brace markers inside [headline] and [description] are highlighted with
/// the current theme's primary color, which makes the widget useful for landing
/// pages and section intros where a few words need extra emphasis without
/// introducing richer markup.
///
/// [description] provides supporting copy displayed below the headline.
/// [headline] supplies the emphasized primary section text.
///
/// ```dart
/// SectionTitle(
///   headline: 'This is the headline, emphasised text.',
///   description: 'This is where the description will go.',
/// );
/// ```
class SectionTitle extends StatelessWidget {
  /// Creates a [SectionTitle] with a required [headline].
  const SectionTitle({
    super.key,
    this.description,
    required this.headline,
    this.headlineStyle,
    this.descriptionStyle,
  });

  /// Supplies optional body text shown below the headline.
  final String? description;

  /// Supplies the main heading text for the section.
  final String headline;

  /// Overrides the default text style used for [headline].
  final TextStyle? headlineStyle;

  /// Overrides the default text style used for [description].
  final TextStyle? descriptionStyle;

  /// Builds the section title and highlights any marked important segments.
  ///
  /// The widget keeps its bottom safe-area inset disabled because it is commonly
  /// placed near the top of a screen or section rather than above system UI.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    TextStyle? defaultHeadlineStyle = headlineStyle ?? textTheme.headlineMedium;
    TextStyle? defaultDescriptionStyle =
        descriptionStyle ?? textTheme.bodyMedium;

    RegExp regExp = RegExp(r'{.*?}', multiLine: true);

    /// Converts brace-delimited fragments into highlighted [TextSpan] segments.
    ///
    /// Underscores are replaced with spaces so lightweight content templates can
    /// preserve emphasis markers without forcing callers to build rich text.
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
                text: (textFinal.substring(
                  initialHelper!,
                  match.start,
                )).replaceAll('_', ' ').replaceAll('{', '').replaceAll('}', ''),
                style: textStyle,
              ),
            );
            initialHelper = match.end;
          }
          text.add(
            TextSpan(
              text: (textFinal.substring(
                match.start,
                match.end,
              )).replaceAll('_', ' ').replaceAll('{', '').replaceAll('}', ''),
              style: textStyle?.copyWith(color: theme.colorScheme.primary),
            ),
          );
          initialHelper = match.end;
        }
        text.add(
          TextSpan(
            text: (textFinal.substring(
              initialHelper!,
              textFinal.length,
            )).replaceAll('_', ' ').replaceAll('{', ' ').replaceAll('}', ' '),
            style: textStyle,
          ),
        );
      } else {
        text.add(TextSpan(text: textFinal, style: textStyle));
      }
      return text;
    }

    List<Widget> items = [
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text.rich(
          TextSpan(children: importantData(headline, defaultHeadlineStyle)),
        ),
      ),
    ];
    if (description != null) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(
              children: importantData(description!, defaultDescriptionStyle),
            ),
          ),
        ),
      );
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
