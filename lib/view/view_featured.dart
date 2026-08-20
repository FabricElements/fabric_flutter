import 'dart:async';

import 'package:flutter/material.dart';

import '../component/smart_image.dart';

/// Provides an informative full-screen view with headline, description, and action button.
///
/// [ViewFeatured] presents a visually striking page with an animated gradient
/// reveal over a background image. The widget is useful for onboarding flows,
/// feature announcements, or call-to-action screens where a strong visual
/// impression is desired.
///
/// Example:
/// ```dart
/// ViewFeatured(
///   headline: 'This is the Featured View',
///   description: 'The featured view is useful for describing upcoming actions...',
///   image: 'https://source.unsplash.com/random',
///   actionLabel: 'GO TO HOME',
///   actionUrl: '/',
///   arguments: {'id': 'random_user_id'},
///   onPressed: () {
///     debugPrint('You pressed the button!');
///   },
/// )
/// ```
class ViewFeatured extends StatefulWidget {
  const ViewFeatured({
    super.key,
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
    required this.image,
    this.onPressed,
  });

  final String? actionLabel;
  final String? actionUrl;
  final Object? arguments;
  final String? description;
  final String? headline;
  final int animationDuration;
  final Color firstGradientAnimationColor;
  final Color secondGradientAnimationColor;
  final Color thirdGradientAnimationColor;
  final String image;
  final GestureTapCallback? onPressed;
  final Widget? child;

  // Make animation optional

  @override
  State<ViewFeatured> createState() => _ViewFeaturedState();
}

class _ViewFeaturedState extends State<ViewFeatured> {
  /// Holds every pending stage timer for the reveal animation.
  ///
  /// All five stages are tracked so each one can be cancelled, both when the
  /// sequence restarts and when the state leaves the tree. Assigning them to a
  /// single field would leave the earlier timers unreachable and still running.
  final List<Timer> _timers = [];
  double _actionOpacityLevel = 0;
  double _headlineOpacityLevel = 0;
  double _descriptionOpacityLevel = 0;
  double _childOpacityLevel = 0;
  late int _animationDuration;
  Color? _firstGradientAnimationColor;
  Color? _secondGradientAnimationColor;
  Color? _thirdGradientAnimationColor;

  /// Cancels and clears every pending stage timer.
  void _cancelTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// Schedules a single animation stage and tracks its timer.
  ///
  /// The [step] value multiplies [_animationDuration] to stagger the stage, and
  /// [apply] mutates the opacity or gradient state for that stage.
  void _scheduleStage(int step, VoidCallback apply) {
    _timers.add(
      Timer(Duration(milliseconds: _animationDuration * step), () {
        if (!mounted) return;
        setState(apply);
      }),
    );
  }

  /// Triggers the reveal animation sequence.
  ///
  /// The animation proceeds through five stages: gradient fade-ins for the
  /// background, followed by opacity transitions for the headline, description,
  /// custom child widget, and action button. Each stage duration is controlled
  /// by [_animationDuration]. Any previously scheduled sequence is cancelled
  /// first so stages cannot overlap or accumulate.
  void animationTrigger() {
    _cancelTimers();
    _scheduleStage(1, () {
      _firstGradientAnimationColor = Colors.transparent;
    });
    _scheduleStage(2, () {
      _secondGradientAnimationColor = Colors.transparent;
      _headlineOpacityLevel = 1.0;
    });
    _scheduleStage(3, () {
      _descriptionOpacityLevel = 1.0;
    });
    _scheduleStage(4, () {
      _childOpacityLevel = 1.0;
    });
    _scheduleStage(5, () {
      _actionOpacityLevel = 1.0;
    });
  }

  @override
  void initState() {
    super.initState();
    _firstGradientAnimationColor = widget.firstGradientAnimationColor;
    _secondGradientAnimationColor = widget.secondGradientAnimationColor;
    _thirdGradientAnimationColor = widget.thirdGradientAnimationColor;
    _animationDuration = widget.animationDuration;
    // Started once here rather than from didChangeDependencies, which fires
    // again on every inherited-widget change (theme, locale, media query) and
    // would otherwise restart the reveal and spawn a fresh set of timers.
    animationTrigger();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Object arguments = widget.arguments ?? {};
    onClick() {
      if (widget.actionUrl != null) {
        Navigator.pushNamed(context, widget.actionUrl!, arguments: arguments);
      }
      if (widget.onPressed != null) {
        widget.onPressed!();
      }
    }

    final textTheme = Theme.of(context).textTheme;
    List<Widget> options = [];
    if (widget.description != null) {
      options.add(
        AnimatedOpacity(
          duration: Duration(milliseconds: _animationDuration),
          opacity: _descriptionOpacityLevel,
          child: SafeArea(
            top: false,
            bottom: widget.actionLabel == null && widget.child == null,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.description!,
                style: textTheme.titleLarge,
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ),
      );
    }
    if (widget.child != null) {
      options.addAll([
        Container(height: 32),
        AnimatedOpacity(
          opacity: _childOpacityLevel,
          duration: Duration(milliseconds: _animationDuration),
          child: widget.child,
        ),
      ]);
    }
    if (widget.actionLabel != null) {
      options.addAll([
        Container(height: 32),
        AnimatedOpacity(
          opacity: _actionOpacityLevel,
          duration: Duration(milliseconds: _animationDuration),
          child: Center(
            child: FloatingActionButton.extended(
              heroTag: 'featured-view-action',
              icon: const Icon(Icons.navigate_next),
              label: Text(widget.actionLabel!.toUpperCase()),
              onPressed: widget.actionLabel != null ? () => onClick() : null,
            ),
          ),
        ),
      ]);
    }
    return Scaffold(
      primary: false,
      body: SizedBox.expand(
        child: InkWell(
          onTap: widget.actionLabel != null ? () => onClick() : null,
          child: Flex(
            direction: Axis.vertical,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    SizedBox.expand(
                      child: SmartImage(
                        key: ValueKey('featured-view-image-${widget.image}'),
                        url: widget.image,
                        format: AvailableOutputFormats.jpeg,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      top: 0,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: _animationDuration),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.5, 1.0],
                            colors: [
                              _firstGradientAnimationColor!,
                              _secondGradientAnimationColor!,
                              _thirdGradientAnimationColor!,
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
                        padding: const EdgeInsets.all(16),
                        child: AnimatedOpacity(
                          duration: Duration(milliseconds: _animationDuration),
                          opacity: _headlineOpacityLevel,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 64),
                            child: SafeArea(
                              top: false,
                              bottom: false,
                              child: Text(
                                widget.headline!,
                                style: textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
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
