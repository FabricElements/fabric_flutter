import 'package:flutter/material.dart';

import 'smart-imgix.dart';

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
  CardButton({
    Key key,
    this.borderRadius = 6,
    this.description,
    this.headline,
    this.height = 300,
    this.margin,
    @required this.image,
    @required this.onPressed,
  }) : super(key: key);
  final double borderRadius;
  final String description;
  final String headline;
  final double height;
  final String image; // Make optional?
  final GestureTapCallback onPressed;
  final EdgeInsetsGeometry margin;

  @override
  _CardButtonState createState() => _CardButtonState();
}

class _CardButtonState extends State<CardButton> {
  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: widget.margin ?? EdgeInsets.symmetric(vertical: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        clipBehavior: Clip.hardEdge,
        child: RawMaterialButton(
          onPressed: () => widget.onPressed(),
          child: Container(
            height: widget.height,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                SizedBox.expand(
                  child: SmartImgix(
                    image: widget.image,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.5, 1.0],
                        colors: [
                          Color.fromRGBO(0, 0, 0, 0.0),
                          Color.fromRGBO(0, 0, 0, 0.3),
                          Color.fromRGBO(0, 0, 0, 0.6),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(top: 64),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          widget.headline != null
                              ? Text(
                                  widget.headline,
                                  style: textTheme.headline4
                                      .copyWith(color: Colors.white),
                                  textAlign: TextAlign.left,
                                )
                              : Container(),
                          widget.description != null
                              ? Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    widget.description,
                                    style: textTheme.bodyText2.copyWith(color: Colors.white),
                                    textAlign: TextAlign.left,
                                  ),
                                )
                              : Container(),
                        ],
                      ),
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
