import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../app_theme_extensions.dart';

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
    this.padding = const EdgeInsets.all(AppTokens.space2),
    this.margin,
    this.emphasized = false,
    this.outlinedStrong = false,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final body = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? (emphasized ? extras.panelAlt : extras.panel),
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        border: Border.all(
          color: outlinedStrong ? extras.borderStrong : extras.border,
          width: outlinedStrong ? AppTokens.borderStrong : AppTokens.border,
        ),
      ),
      child: child,
    );

    if (onTap == null) {
      return body;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusM),
      child: body,
    );
  }
}
