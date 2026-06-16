import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../app_theme_extensions.dart';
import '../glass/glass_surface.dart';

class AppPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool emphasized;
  final bool outlinedStrong;
  final Color? color;
  final VoidCallback? onTap;

  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space3),
    this.margin,
    this.emphasized = false,
    this.outlinedStrong = false,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return GlassSurface(
      padding: padding,
      margin: margin,
      borderRadius: BorderRadius.circular(AppTokens.radiusL),
      fill: color ?? (emphasized ? extras.glassFillStrong : extras.glassFill),
      borderColor: outlinedStrong ? extras.borderStrong : extras.glassBorder,
      borderWidth: outlinedStrong ? AppTokens.borderStrong : AppTokens.border,
      onTap: onTap,
      child: child,
    );
  }
}
