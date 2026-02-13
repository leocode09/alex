import 'package:flutter/material.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_badge.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      {
        'title': 'Low Stock Alert',
        'message': 'Sugar is running low (12 items left)',
        'time': '2h ago',
        'type': 'warning',
        'read': false,
      },
      {
        'title': 'New Sale',
        'message': 'Sale completed: \$5,000',
        'time': '3h ago',
        'type': 'success',
        'read': true,
      },
      {
        'title': 'System Update',
        'message': 'New version available',
        'time': '1d ago',
        'type': 'info',
        'read': true,
      },
    ];

    return AppPageScaffold(
      title: 'Notifications',
      actions: [
        IconButton(
          icon: const Icon(Icons.done_all),
          onPressed: () {},
        ),
        const SizedBox(width: 6),
      ],
      child: ListView.separated(
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space2),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          final isRead = notification['read'] as bool;
          return AppPanel(
            emphasized: !isRead,
            outlinedStrong: !isRead,
            padding: const EdgeInsets.all(AppTokens.space3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTokens.paperAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTokens.line),
                  ),
                  child: Icon(
                    _getIcon(notification['type'] as String),
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTokens.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'] as String,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: isRead
                                        ? FontWeight.w600
                                        : FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            notification['time'] as String,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification['message'] as String,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTokens.mutedText,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          AppBadge(
                            label: _badgeLabel(notification['type'] as String),
                            tone: _badgeTone(notification['type'] as String),
                          ),
                          if (!isRead) ...[
                            const SizedBox(width: 8),
                            const AppBadge(
                                label: 'Unread', tone: AppBadgeTone.accent),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _badgeLabel(String type) {
    switch (type) {
      case 'warning':
        return 'Warning';
      case 'success':
        return 'Success';
      case 'info':
        return 'Info';
      default:
        return 'Notice';
    }
  }

  AppBadgeTone _badgeTone(String type) {
    switch (type) {
      case 'warning':
        return AppBadgeTone.warning;
      case 'success':
        return AppBadgeTone.success;
      case 'info':
        return AppBadgeTone.accent;
      default:
        return AppBadgeTone.neutral;
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'success':
        return Icons.check_circle_outline;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }
}
