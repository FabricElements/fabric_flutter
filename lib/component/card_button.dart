import 'package:flutter/material.dart';

import 'smart_image.dart';

/// Displays a large tappable card with an image and optional supporting text.
///
/// Builds a dashboard-style call to action where the image fills the card and a
/// gradient keeps [headline] and [description] readable near the bottom edge.
/// [borderRadius] expresses the intended corner radius for the card styling,
/// [height] controls the vertical space reserved for the layout, [margin]
/// provides outer spacing, [image] supplies the background asset URL, and
/// [onPressed] handles taps across the full card surface.
///
/// ```dart
/// CardButton(
///   headline: 'Card Button Example',
///   description: 'This is an example of a really cool button',
///   image: 'https://images.unsplash.com/photo-1503981473451-8b604df73b91',
///   onPressed: () {
///     debugPrint('Do something here!');
///   },
/// );
/// ```
class CardButton extends StatefulWidget {
  /// Creates a [CardButton] that turns a visual card into a single tap target.
  ///
  /// Keeps [image] and [onPressed] required so the widget always remains useful
  /// as an actionable card even when [headline] or [description] are `null`.
  const CardButton({
    super.key,
    this.borderRadius = 6,
    this.description,
    this.headline,
    this.height = 300,
    this.margin,
    required this.image,
    required this.onPressed,
    this.semanticsLabel,
    this.automationKey,
    this.semanticHint,
  });

  /// Stores the preferred border radius for the surrounding card styling.
  ///
  /// Exposes the value so parent widgets can configure the intended curvature of
  /// the visual card, even though the current implementation does not apply it.
  final double borderRadius;

  /// Stores the optional supporting text shown beneath [headline].
  ///
  /// Allows the card to present extra context when the value is not `null`.
  final String? description;

  /// Stores the prominent title rendered over the image.
  ///
  /// Allows the card to show a primary label when the value is not `null`.
  final String? headline;

  /// Stores the overall height reserved for the card content.
  ///
  /// Gives layouts a predictable vertical footprint for the tappable surface.
  final double height;

  /// Stores the image URL rendered behind the text overlay.
  ///
  /// Supplies the source that [SmartImage] loads for the card background.
  final String image; // Make optional?

  /// Stores the callback that runs when the user taps the card.
  ///
  /// Keeps interaction handling outside the widget so callers can decide what
  /// navigation or action should occur.
  final GestureTapCallback onPressed;

  /// Stores the optional outer spacing applied around the card.
  ///
  /// Allows the widget to fit varied list and grid layouts without wrappers.
  final EdgeInsetsGeometry? margin;

  /// Overrides the label exposed to accessibility tools and autonomous agents.
  ///
  /// Falls back to [headline] first, then [description], when `null`.
  final String? semanticsLabel;

  /// Assigns a deterministic identifier to the semantics node.
  ///
  /// Maps to [Semantics.identifier] in the accessibility tree.
  final String? automationKey;

  /// Provides structural, non-visual instructions to autonomous agents.
  ///
  /// Maps to [Semantics.hint] in the accessibility tree.
  final String? semanticHint;

  /// Creates the mutable [State] used to render the card.
  ///
  /// Returns a [_CardButtonState] so the widget can participate in the
  /// [StatefulWidget] lifecycle.
  @override
  State<CardButton> createState() => _CardButtonState();
}

/// Holds the mutable presentation state for [CardButton].
///
/// Keeps the widget in the [StatefulWidget] lifecycle while building the image,
/// gradient overlay, and tap handling as a single visual control.
class _CardButtonState extends State<CardButton> {
  /// Builds the card with a full-bleed image and readable text overlay.
  ///
  /// Uses the ambient [BuildContext] to read theme values and keeps the image
  /// and text in one tappable region so hit testing behaves like a single
  /// button.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Semantics(
      label: widget.semanticsLabel ?? widget.headline ?? widget.description,
      identifier: widget.automationKey,
      hint: widget.semanticHint,
      enabled: true,
      container: true,
      child: Container(
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
                      key: ValueKey('card-button-image-${widget.image}'),
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
      ),
    );
  }
}
