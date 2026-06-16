import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_theme_extensions.dart';
import '../app_tokens.dart';
import 'noise_texture.dart';

/// A reusable frosted-glass surface: blurs what is behind it, lays a
/// translucent fill on top, adds a hairline border, a soft top highlight and a
/// faint grain. Used by [AppPanel] and any other glass element (tiles, dialogs,
/// sheets).
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color? fill;
  final Color? borderColor;
  final double borderWidth;
  final bool highlight;
  final bool showNoise;
  final VoidCallback? onTap;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space2),
    this.margin,
    BorderRadius? borderRadius,
    this.blurSigma = AppTokens.blurPanel,
    this.fill,
    this.borderColor,
    this.borderWidth = AppTokens.border,
    this.highlight = true,
    this.showNoise = true,
    this.onTap,
  }) : borderRadius =
            borderRadius ?? const BorderRadius.all(Radius.circular(AppTokens.radiusM));

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final resolvedFill = fill ?? extras.glassFill;
    final resolvedBorder = borderColor ?? extras.glassBorder;

    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (highlight) {
      content = Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      extras.glassHighlight,
                      extras.glassHighlight.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.18],
                  ),
                ),
              ),
            ),
          ),
          content,
        ],
      );
    }

    if (showNoise) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: NoiseOverlay(
              tint: extras.noiseColor,
              opacity: extras.noiseOpacity * 0.6,
            ),
          ),
        ],
      );
    }

    Widget surface = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: resolvedFill,
            borderRadius: borderRadius,
            border: Border.all(color: resolvedBorder, width: borderWidth),
          ),
          child: content,
        ),
      ),
    );

    if (onTap != null) {
      surface = Stack(
        children: [
          surface,
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
              ),
            ),
          ),
        ],
      );
    }

    if (margin != null) {
      return Padding(padding: margin!, child: surface);
    }
    return surface;
  }
}
