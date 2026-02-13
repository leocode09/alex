import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../app_theme_extensions.dart';
import 'app_panel.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return AppPanel(
      emphasized: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: extras.muted),
            const SizedBox(height: AppTokens.space2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTokens.space1),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: extras.muted,
                    ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTokens.space3),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
