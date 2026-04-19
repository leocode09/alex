import 'package:flutter/material.dart';

import '../../../design_system/app_theme_extensions.dart';
import '../../../design_system/app_tokens.dart';
import '../../../design_system/widgets/app_panel.dart';

/// Richer stat tile than `AppStatTile` — supports a big value, icon,
/// muted subtitle, optional tone (coloured icon / accent line), and
/// an optional delta string (e.g. "+12% vs yesterday") rendered in
/// the bottom-right of the card.
class AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;
  final String? delta;
  final Color? tone;
  final VoidCallback? onTap;

  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.delta,
    this.tone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.appExtras;
    final resolvedTone = tone ?? theme.colorScheme.primary;

    return AppPanel(
      emphasized: true,
      onTap: onTap,
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: resolvedTone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTokens.radiusS),
                ),
                child: Icon(icon, size: 18, color: resolvedTone),
              ),
              const SizedBox(width: AppTokens.space2),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                        color: extras.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFamily: 'IBMPlexMono',
                ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                    color: extras.muted,
                  ),
            ),
          ],
          if (delta != null && delta!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                delta!,
                style: theme.textTheme.labelSmall?.copyWith(
                      color: resolvedTone,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
