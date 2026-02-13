import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../app_theme_extensions.dart';

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: AppTokens.space2),
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final actionEnabled = actionLabel != null && onAction != null;
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (actionEnabled)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusS),
                  side: BorderSide(color: extras.border),
                ),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
