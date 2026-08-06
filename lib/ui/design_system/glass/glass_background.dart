import 'package:flutter/material.dart';

import '../app_theme_extensions.dart';
import 'noise_texture.dart';

/// App-wide glassmorphism backdrop: a soft gradient base with a few large,
/// heavily blurred color "blobs" and a faint film-grain overlay. Glass panels
/// layered on top blur and pick up this color.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  extras.backdropBase,
                  Color.alphaBlend(
                    extras.backdropCool.withValues(alpha: 0.5),
                    extras.backdropBase,
                  ),
                  extras.backdropBase,
                ],
              ),
            ),
          ),
          _Blob(
            alignment: const Alignment(-1.1, -1.2),
            diameter: 360,
            color: extras.backdropWarm,
          ),
          _Blob(
            alignment: const Alignment(1.3, -0.6),
            diameter: 320,
            color: extras.backdropAmber,
          ),
          _Blob(
            alignment: const Alignment(-0.8, 1.2),
            diameter: 380,
            color: extras.backdropCool,
          ),
          _Blob(
            alignment: const Alignment(1.1, 1.3),
            diameter: 300,
            color: extras.backdropWarm,
          ),
          Positioned.fill(
            child: NoiseOverlay(
              tint: extras.noiseColor,
              opacity: extras.noiseOpacity,
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Alignment alignment;
  final double diameter;
  final Color color;

  const _Blob({
    required this.alignment,
    required this.diameter,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // A wide, soft radial falloff reproduces the old sigma-90 Gaussian blur of
    // a smaller circle at zero image-filter cost (a blurred radial gradient is
    // itself just a softer radial gradient). The extra diameter accounts for
    // the ~3-sigma spread the blur used to add.
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: diameter * 2.2,
          height: diameter * 2.2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.42),
                color.withValues(alpha: 0.28),
                color.withValues(alpha: 0.10),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
