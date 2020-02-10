import 'package:flutter/material.dart';

/// SectionTitle is a widget used for emphasis and a screen which can show the start of a section.
///
/// [description] Description for the section, displayed in the widget.
/// [headline] Headline for the section, emphasis text.
/// SectionTitle(
///   headline: "This is the headline, emphasised text.",
///   description: "This is where the description will go.",
/// );
class SectionTitle extends StatefulWidget {
  SectionTitle({
    Key key,
    this.description,
    @required this.headline,
    this.condensed = false,
  }) : super(key: key);
  final String description;
  final String headline;
  final bool condensed;

  @override
  _SectionTitleState createState() => new _SectionTitleState();
}

class _SectionTitleState extends State<SectionTitle> {
  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    RegExp regExp = new RegExp(
      r"{(?:.*?)}",
      multiLine: true,
    );
    List<TextSpan> importantData(String textConvert, String type) {
      List<TextSpan> text = [];
      String textFinal = textConvert;
      int initialHelper = 0;
      Iterable matches = regExp.allMatches(textFinal);
      TextStyle sizeBase = textTheme.headline;
      TextStyle titleWhite = sizeBase;
      TextStyle titleColor = sizeBase;
      if (type == "title") {
        sizeBase = textTheme.display2;
        titleWhite = sizeBase.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        );
        titleColor = sizeBase.copyWith(
          color: Colors.greenAccent.shade400,
          fontWeight: FontWeight.w600,
        );
      } else {
        if (widget.condensed) {
          sizeBase = textTheme.title.copyWith(fontWeight: FontWeight.w400);
          titleWhite = sizeBase;
          titleColor = sizeBase;
        }
        titleWhite = titleWhite.copyWith(color: Colors.grey.shade300);
        titleColor = titleColor.copyWith(
          color: Colors.greenAccent.shade400,
        );
      }
      if (matches.length > 0) {
        matches.forEach((match) {
          if (match.start > initialHelper) {
            text.add(
              TextSpan(
                text: (textFinal.substring(initialHelper, match.start))
                    .replaceAll("_", " ")
                    .replaceAll("{", "")
                    .replaceAll("}", ""),
                style: titleWhite,
              ),
            );
            initialHelper = match.end;
          }
          text.add(
            TextSpan(
              text: (textFinal.substring(match.start, match.end))
                  .replaceAll("_", " ")
                  .replaceAll("{", "")
                  .replaceAll("}", ""),
              style: titleColor,
            ),
          );
          initialHelper = match.end;
        });
        text.add(
          TextSpan(
            text: (textFinal.substring(initialHelper, textFinal.length))
                .replaceAll("_", " ")
                .replaceAll("{", " ")
                .replaceAll("}", " "),
            style: titleWhite,
          ),
        );
      } else {
        text.add(TextSpan(
          text: textFinal,
          style: titleWhite,
        ));
      }
      return text;
    }

    List<Widget> items = [
      Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text.rich(
          TextSpan(
            children: importantData(widget.headline, "title"),
          ),
        ),
      ),
    ];
    if (widget.description != null) {
      items.add(Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Text.rich(
          TextSpan(
            children: importantData(widget.description, "subtitle"),
          ),
        ),
      ));
    }
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Wrap(
          children: items,
        ),
      ),
    );
  }
}
