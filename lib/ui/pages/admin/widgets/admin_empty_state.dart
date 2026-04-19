import 'package:flutter/material.dart';

import '../../../design_system/widgets/app_empty_state.dart';

/// Admin-flavoured empty state with common defaults: an icon, a title,
/// an optional subtitle, and either a "Clear filters" or "Refresh"
/// action when the list is empty because of filters / offline.
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: icon,
      title: title,
      subtitle: subtitle,
      action: (actionLabel != null && onAction != null)
          ? FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel!),
            )
          : null,
    );
  }
}
