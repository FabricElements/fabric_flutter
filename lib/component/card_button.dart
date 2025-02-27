import 'package:flutter/material.dart';

import 'smart_image.dart';

/// CardButton is a versatile card style raw material button containing an image and additional customization options.
///
/// [borderRadius] This is to set the border radius for the card.
/// [description] For adding a text description for the button.
/// [headline] For adding a larger text headline for the button.
/// [height] Is used to set the height for the card button.
/// [image] This is to set the image for the widget.
/// [onPressed] This is the function used for when the button is pressed.
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

  final double borderRadius;
  final String? description;
  final String? headline;
  final double height;
  final String image; // Make optional?
  final GestureTapCallback onPressed;
  final EdgeInsetsGeometry? margin;

  @override
  State<CardButton> createState() => _CardButtonState();
}

class _CardButtonState extends State<CardButton> {
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
                                  color: theme.colorScheme.onSurface),
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
                                    color: theme.colorScheme.onSurface),
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
