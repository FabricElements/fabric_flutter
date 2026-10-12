import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart';

/// A closed outline that morphs between a soft square and a lobed "cookie".
///
/// The outline is a superellipse, so [exponent] moves it from a circle (2) to a
/// squircle (about 4 to 5). [lobes] and [amplitude] add the cookie's scalloped
/// edge: with `amplitude` at 0 the outline has no lobes, and larger values push
/// the edge in and out around the circumference. Interpolating the three values
/// with [lerp] morphs the shape, which is what Material 3 Expressive uses for
/// state changes.
class ExpressiveShapeBorder extends ShapeBorder {
  /// Creates an outline with the given superellipse [exponent], lobe count and
  /// lobe [amplitude].
  const ExpressiveShapeBorder({
    this.exponent = 4.5,
    this.lobes = 0,
    this.amplitude = 0,
  });

  /// Soft square that Expressive components rest on.
  static const squircle = ExpressiveShapeBorder(exponent: 4.5);

  /// Lobed cookie that Expressive components morph into when active.
  static const cookie = ExpressiveShapeBorder(
    exponent: 2.6,
    lobes: 8,
    amplitude: 0.07,
  );

  /// Superellipse exponent. 2 is a circle, larger values are squarer.
  final double exponent;

  /// Number of scalloped lobes around the outline. Ignored when [amplitude] is 0.
  final int lobes;

  /// Depth of the lobes as a fraction of the half-size. 0 gives no lobes.
  final double amplitude;

  /// Returns the shape at [t] between [a] and [b], where `t == 0` is [a].
  static ExpressiveShapeBorder lerp(
    ExpressiveShapeBorder a,
    ExpressiveShapeBorder b,
    double t,
  ) {
    final lobeCount = t < 0.5 ? a.lobes : b.lobes;
    return ExpressiveShapeBorder(
      exponent: lerpDouble(a.exponent, b.exponent, t)!,
      lobes: lobeCount,
      amplitude: lerpDouble(a.amplitude, b.amplitude, t)!,
    );
  }

  static const int _samples = 180;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final center = rect.center;
    final halfWidth = rect.width / 2;
    final halfHeight = rect.height / 2;
    final power = 2 / exponent;
    final path = Path();
    for (var i = 0; i <= _samples; i++) {
      final theta = 2 * math.pi * i / _samples;
      final cosT = math.cos(theta);
      final sinT = math.sin(theta);
      var x = _signedPow(cosT, power);
      var y = _signedPow(sinT, power);
      if (amplitude != 0 && lobes > 0) {
        // Normalised so the outermost point lands on the rect edge.
        final modulation =
            (1 + amplitude * math.cos(lobes * theta)) / (1 + amplitude);
        x *= modulation;
        y *= modulation;
      }
      final point = Offset(
        center.dx + x * halfWidth,
        center.dy + y * halfHeight,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  /// Fills are painted by the surrounding decoration; this border draws no side.
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => ExpressiveShapeBorder(
    exponent: exponent,
    lobes: lobes,
    amplitude: amplitude * t,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is ExpressiveShapeBorder) return lerp(a, this, t);
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is ExpressiveShapeBorder) return lerp(this, b, t);
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      other is ExpressiveShapeBorder &&
      other.exponent == exponent &&
      other.lobes == lobes &&
      other.amplitude == amplitude;

  @override
  int get hashCode => Object.hash(exponent, lobes, amplitude);

  /// Raises the magnitude of [value] to [power] and keeps its sign.
  static double _signedPow(double value, double power) {
    final magnitude = math.pow(value.abs(), power).toDouble();
    return value < 0 ? -magnitude : magnitude;
  }
}
