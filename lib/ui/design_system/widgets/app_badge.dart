import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../app_theme_extensions.dart';

enum AppBadgeTone { neutral, accent, success, warning, danger }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeTone tone;

  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final colors = _resolveColors(context, extras);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(AppTokens.radiusS),
        border: Border.all(color: colors.$2, width: AppTokens.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.$3,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  (Color, Color, Color) _resolveColors(
      BuildContext context, AppThemeExtras extras) {
    final accent = Theme.of(context).colorScheme.primary;
    switch (tone) {
      case AppBadgeTone.accent:
        return (extras.accentSoft, accent, accent);
      case AppBadgeTone.success:
        return (
          extras.success.withValues(alpha: 0.1),
          extras.success,
          extras.success
        );
      case AppBadgeTone.warning:
        return (
          extras.warning.withValues(alpha: 0.1),
          extras.warning,
          extras.warning
        );
      case AppBadgeTone.danger:
        return (
          extras.danger.withValues(alpha: 0.1),
          extras.danger,
          extras.danger
        );
      case AppBadgeTone.neutral:
        return (extras.panelAlt, extras.border, extras.muted);
    }
  }
}
