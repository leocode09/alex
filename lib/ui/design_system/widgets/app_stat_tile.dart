import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../app_theme_extensions.dart';
import 'app_panel.dart';

class AppStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final String? subtitle;
  final Color? tone;

  const AppStatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.subtitle,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return AppPanel(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: 18,
                  color: tone ?? Theme.of(context).colorScheme.primary,
                ),
              if (icon != null) const SizedBox(width: AppTokens.space1),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: extras.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space1),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFamily: 'IBMPlexMono',
                ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: extras.muted,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
