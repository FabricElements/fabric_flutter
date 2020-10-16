import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'smart-imgix.dart';

/// This Widget provides a informative view, consisting of a strong headline, optional description and action button
///
/// [actionLabel] Text provided for the action button.
/// [actionUrl] Navigation destination for when action button is pressed.
/// [arguments] Optional arguments which may be necessary for certain navigation url's.
/// [description] Descriptive text provided for the view.
/// [headline] Strong headline for the view.
/// [animationDuration] The duration of time it takes for each animation stage to finish. Total duration time is animationDuration * 4.
/// [firstGradientAnimationColor] The color of the top animation gradient.
/// [secondGradientAnimationColor] The color of the mid animation gradient.
/// [thirdGradientAnimationColor] The color of the bottom animation gradient.
/// [image] Image url to load an image from the cloud to be displayed on the view.
/// [onPressed] Optional arguments to be provided to the onPressed action, such as updating a firestore document.
/// ```dart
/// FeaturedView(
///   headline: "This is the Featured View",
///   description:
///       "The featured view is useful for describing upcoming actions or giving feedback to the user.",
///   image:
///       "https://source.unsplash.com/random",
///   actionLabel: "GO TO HOME",
///   actionUrl: "/",
///   arguments: {"id": "random_user_id"},
///   onPressed: () {
///     Print("You pressed the button! You can perform any action here.");
///   }
/// ),
/// ```
class FeaturedView extends StatefulWidget {
  FeaturedView({
    Key key,
    this.actionLabel,
    this.actionUrl,
    this.arguments,
    this.description,
    this.headline,
    this.animationDuration = 250,
    this.firstGradientAnimationColor = Colors.transparent,
    this.secondGradientAnimationColor = Colors.transparent,
    this.thirdGradientAnimationColor = Colors.transparent,
    this.child,
    @required this.image,
    this.onPressed,
  }) : super(key: key);
  final String actionLabel;
  final String actionUrl;
  final Object arguments;
  final String description;
  final String headline;
  final int animationDuration;
  final Color firstGradientAnimationColor;
  final Color secondGradientAnimationColor;
  final Color thirdGradientAnimationColor;
  final String image;
  final GestureTapCallback onPressed;
  final Widget child;

  // Make animation optional

  @override
  _FeaturedViewState createState() => _FeaturedViewState();
}

class _FeaturedViewState extends State<FeaturedView> {
  Timer _timer;
  double _actionOpacityLevel = 0;
  double _headlineOpacityLevel = 0;
  double _descriptionOpacityLevel = 0;
  double _childOpacityLevel = 0;
  int _animationDuration;
  Color _firstGradientAnimationColor;
  Color _secondGradientAnimationColor;
  Color _thirdGradientAnimationColor;

  /// Triggers the animation, the speed of the animation can be altered by [_animationDuration]
  void animationTrigger() {
    _timer = Timer(Duration(milliseconds: _animationDuration), () {
      if (mounted) {
        setState(() {
          _firstGradientAnimationColor = Colors.transparent;
        });
      }
    });
    _timer = Timer(Duration(milliseconds: _animationDuration * 2), () {
      if (mounted) {
        setState(() {
          _secondGradientAnimationColor = Colors.transparent;
          _headlineOpacityLevel = 1.0;
        });
      }
    });
    _timer = Timer(Duration(milliseconds: _animationDuration * 3), () {
      if (mounted) {
        setState(() {
          _descriptionOpacityLevel = 1.0;
        });
      }
    });
    _timer = Timer(Duration(milliseconds: _animationDuration * 4), () {
      if (mounted) {
        setState(() {
          _childOpacityLevel = 1.0;
        });
      }
    });
    _timer = Timer(Duration(milliseconds: _animationDuration * 5), () {
      if (mounted) {
        setState(() {
          _actionOpacityLevel = 1.0;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    animationTrigger();
  }

  @override
  void initState() {
    super.initState();
    _firstGradientAnimationColor = widget.firstGradientAnimationColor;
    _secondGradientAnimationColor = widget.secondGradientAnimationColor;
    _thirdGradientAnimationColor = widget.thirdGradientAnimationColor;
    _animationDuration = widget.animationDuration;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Object arguments = widget.arguments ?? {};
    onClick() {
      if (widget.actionUrl != null) {
        Navigator.pushNamed(context, widget.actionUrl, arguments: arguments);
      }
      if (widget.onPressed != null) {
        widget.onPressed();
      }
    }

    final TextTheme textTheme = Theme.of(context).textTheme;
    List<Widget> options = [];
    if (widget.description != null) {
      options.add(AnimatedOpacity(
        duration: Duration(milliseconds: _animationDuration),
        opacity: _descriptionOpacityLevel,
        child: Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            widget.description,
            style: textTheme.headline5,
            textAlign: TextAlign.left,
          ),
        ),
      ));
    }
    if (widget.child != null) {
      options.addAll([
        Container(
          height: 32,
        ),
        AnimatedOpacity(
          opacity: _childOpacityLevel,
          duration: Duration(milliseconds: _animationDuration),
          child: widget.child,
        ),
      ]);
    }
    if (widget.actionLabel != null) {
      options.addAll([
        Container(
          height: 32,
        ),
        AnimatedOpacity(
          opacity: _actionOpacityLevel,
          duration: Duration(milliseconds: _animationDuration),
          child: SizedBox(
            width: double.infinity,
            child: RaisedButton(
              textColor: Colors.white,
              child: Text(widget.actionLabel.toUpperCase()),
              onPressed: widget.actionLabel != null ? () => onClick() : null,
            ),
          ),
        ),
      ]);
    }
    return Scaffold(
      body: SizedBox.expand(
        child: RawMaterialButton(
          onPressed: widget.actionLabel != null ? () => onClick() : null,
          child: Flex(
            direction: Axis.vertical,
            children: <Widget>[
              Expanded(
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
                      top: 0,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: _animationDuration),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.5, 1.0],
                            colors: [
                              _firstGradientAnimationColor,
                              _secondGradientAnimationColor,
                              _thirdGradientAnimationColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(16),
                        child: AnimatedOpacity(
                          duration: Duration(milliseconds: _animationDuration),
                          opacity: _headlineOpacityLevel,
                          child: Padding(
                            padding: EdgeInsets.only(top: 64),
                            child: SafeArea(
                              top: false,
                              bottom: false,
                              child: Text(
                                widget.headline,
                                style: textTheme.headline3.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: 16,
                  bottom: widget.child == null ? 16 : 0,
                  left: 16,
                  right: 16,
                ),
                child: SafeArea(
                  top: false,
                  bottom: widget.actionLabel != null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: options,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
