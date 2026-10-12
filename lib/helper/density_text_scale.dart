import 'package:flutter/material.dart';

/// Returns the global text scale for a [VisualDensity].
///
/// Text follows the density control the same way spacing does. Each step below
/// standard shrinks text by 4%, and each step above standard grows it by 8%, so
/// the largest setting is noticeably bigger without overflowing typical layouts.
/// Density values outside −2 to 2 are clamped. Standard density returns `1.0`.
///
/// Pass only an explicit user choice. [VisualDensity.adaptivePlatformDensity]
/// resolves to compact on desktop, which would shrink all text. Map an
/// adaptive setting to [VisualDensity.standard] before calling this.
double densityTextScale(VisualDensity density) {
  final steps = density.vertical.clamp(-2.0, 2.0);
  if (steps < 0) return 1.0 + 0.04 * steps;
  return 1.0 + 0.08 * steps;
}

/// Applies the density text scale to every text inside [child].
///
/// Place it once at the root of the app so all routes inherit the scale. When
/// [systemTextScale] is `true`, the operating system text scale is multiplied
/// in, clamped to 1.0–2.0. It is off by default because honouring the OS scale
/// needs a visual pass on every screen first.
class DensityTextScaler extends StatelessWidget {
  /// Creates a [DensityTextScaler] that scales [child] by [density].
  const DensityTextScaler({
    super.key,
    required this.density,
    required this.child,
    this.systemTextScale = false,
  });

  /// The visual density that sets the text scale.
  final VisualDensity density;

  /// The subtree whose text is scaled.
  final Widget child;

  /// Whether the operating system text scale is multiplied in.
  final bool systemTextScale;

  @override
  Widget build(BuildContext context) {
    final system = systemTextScale
        ? MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0)
        : 1.0;
    final scale = system * densityTextScale(density);
    return Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    );
  }
}
