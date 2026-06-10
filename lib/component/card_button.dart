import 'package:flutter/material.dart';

import 'smart_image.dart';

/// Displays a large tappable card with an image and optional supporting text.
///
/// This widget is useful for dashboards and landing pages where the card itself
/// acts as the call to action. The image fills the background, while the text
/// overlay stays readable by applying a gradient near the bottom edge.
///
/// [borderRadius] configures the intended corner radius for the card.
/// [description] adds supporting text below the main title.
/// [headline] adds the primary title displayed over the image.
/// [height] controls the vertical space reserved for the card.
/// [image] provides the image source shown behind the text overlay.
/// [onPressed] handles taps on the card.
///
/// ```dart
/// CardButton(
///   headline: "Card Button Example",
///   description: "This is an example of a really cool button",
///   image: "https://images.unsplash.com/photo-1503981473451-8b604df73b91",
///   onPressed: () {
///     print("Do something here!");
///   },
/// );
/// ```
class CardButton extends StatefulWidget {
  /// Creates a [CardButton] that turns a visual card into a single tap target.
  ///
  /// Keeping [image] and [onPressed] required ensures the widget remains useful
  /// as an actionable card even when [headline] or [description] are omitted.
  const CardButton({
    super.key,
    this.borderRadius = 6,
    this.description,
    this.headline,
    this.height = 300,
    this.margin,
    required this.image,
    required this.onPressed,
  });

  /// Exposes the preferred border radius for the surrounding card styling.
  final double borderRadius;

  /// Supplies optional supporting text shown beneath [headline].
  final String? description;

  /// Supplies the prominent title rendered over the image.
  final String? headline;

  /// Sets the overall height reserved for the card content.
  final double height;

  /// Provides the image URL rendered behind the text overlay.
  final String image; // Make optional?

  /// Runs when the user taps the card.
  final GestureTapCallback onPressed;

  /// Adds optional outer spacing so the card can fit varied list and grid layouts.
  final EdgeInsetsGeometry? margin;

  /// Creates the mutable state used to render the card.
  @override
  State<CardButton> createState() => _CardButtonState();
}

/// Holds the build logic for [CardButton].
class _CardButtonState extends State<CardButton> {
  /// Builds the card with a full-bleed image and readable text overlay.
  ///
  /// The widget keeps the tappable area unified so both the image and text
  /// behave like a single button during hit testing.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Container(
      padding: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        color: theme.colorScheme.surfaceContainerHighest,
        clipBehavior: Clip.hardEdge,
        child: RawMaterialButton(
          onPressed: () => widget.onPressed(),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                SizedBox.expand(
                  child: SmartImage(
                    url: widget.image,
                    format: AvailableOutputFormats.jpeg,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    // padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.4, 0.7],
                        colors: [
                          theme.colorScheme.surface.withValues(alpha: 0.5),
                          theme.colorScheme.surface.withValues(alpha: 0.9),
                          theme.colorScheme.surface.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                    child: ListTile(
                      title: widget.headline != null
                          ? Text(
                              widget.headline!,
                              style: textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                            )
                          : null,
                      subtitle: widget.description != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                widget.description!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                                softWrap: true,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
