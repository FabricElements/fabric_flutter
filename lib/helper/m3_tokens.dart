import 'package:flutter/widgets.dart';

/// Material 3 corner radius scale, in logical pixels.
///
/// Use these instead of literal radii so shapes stay consistent across
/// components.
abstract final class M3Shape {
  /// Square corners (0dp).
  static const double none = 0;

  /// Extra-small corners (4dp), e.g. menus, snackbars, text fields.
  static const double extraSmall = 4;

  /// Small corners (8dp), e.g. chips.
  static const double small = 8;

  /// Medium corners (12dp), e.g. cards.
  static const double medium = 12;

  /// Large corners (16dp), e.g. FABs, navigation drawers.
  static const double large = 16;

  /// Extra-large corners (28dp), e.g. dialogs, bottom sheets.
  static const double extraLarge = 28;

  /// Fully rounded corners, e.g. buttons and badges.
  static const double full = 999;

  /// Returns a circular [BorderRadius] for [radius].
  static BorderRadius circular(double radius) =>
      BorderRadius.all(Radius.circular(radius));
}

/// Spring motion shared by the Material 3 Expressive components.
///
/// Expressive state changes overshoot and settle instead of easing in a fixed
/// curve. The damping ratio is about 0.45, so a change overshoots once and
/// settles within roughly 400ms.
abstract final class M3ExpressiveMotion {
  /// Spring that drives press and selection changes.
  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 700,
    damping: 24,
  );
}

/// Material 3 motion duration and easing tokens.
abstract final class M3Motion {
  /// 50ms — micro feedback.
  static const Duration short1 = Duration(milliseconds: 50);

  /// 100ms — selection controls.
  static const Duration short2 = Duration(milliseconds: 100);

  /// 150ms — small fades.
  static const Duration short3 = Duration(milliseconds: 150);

  /// 200ms — small component changes.
  static const Duration short4 = Duration(milliseconds: 200);

  /// 250ms — component expansion.
  static const Duration medium1 = Duration(milliseconds: 250);

  /// 300ms — standard transitions.
  static const Duration medium2 = Duration(milliseconds: 300);

  /// 350ms — larger component transitions.
  static const Duration medium3 = Duration(milliseconds: 350);

  /// 400ms — full-surface transitions.
  static const Duration medium4 = Duration(milliseconds: 400);

  /// 450ms — long, emphasized transitions.
  static const Duration long1 = Duration(milliseconds: 450);

  /// 500ms — long, emphasized transitions.
  static const Duration long2 = Duration(milliseconds: 500);

  /// 550ms — long, emphasized transitions.
  static const Duration long3 = Duration(milliseconds: 550);

  /// 600ms — the longest emphasized transitions.
  static const Duration long4 = Duration(milliseconds: 600);

  /// Standard easing for elements that start and end on screen.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Standard easing for elements entering the screen.
  static const Curve standardDecelerate = Cubic(0, 0, 0, 1);

  /// Standard easing for elements leaving the screen.
  static const Curve standardAccelerate = Cubic(0.3, 0, 1, 1);

  /// Emphasized easing for elements entering the screen.
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);

  /// Emphasized easing for elements leaving the screen.
  static const Curve emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);

  /// Whether the platform asked to reduce or disable animations.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Returns [duration], or [Duration.zero] when [reduceMotion] is true.
  static Duration resolve(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;
}
