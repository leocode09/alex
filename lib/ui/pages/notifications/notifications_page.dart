import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      {
        'title': 'Low Stock Alert',
        'message': 'Sugar is running low (12 items left)',
        'time': '2 hours ago',
        'type': 'warning',
        'read': false,
      },
      {
        'title': 'New Sale',
        'message': 'Sale completed: 5,000 RWF',
        'time': '3 hours ago',
        'type': 'success',
        'read': true,
      },
      {
        'title': 'System Update',
        'message': 'New version available',
        'time': '1 day ago',
        'type': 'info',
        'read': true,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Mark all as read
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications marked as read')),
              );
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('No notifications'),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: notification['read'] as bool ? null : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getNotificationColor(notification['type'] as String),
                      child: Icon(
                        _getNotificationIcon(notification['type'] as String),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      notification['title'] as String,
                      style: TextStyle(
                        fontWeight: notification['read'] as bool
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification['message'] as String),
                        const SizedBox(height: 4),
                        Text(
                          notification['time'] as String,
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () {
                      // TODO: Handle notification tap
                    },
                  ),
                );
              },
            ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'warning':
        return AppTheme.amberSae;
      case 'success':
        return AppTheme.greenPantone;
      case 'info':
        return AppTheme.greenDark;
      case 'error':
        return AppTheme.amberDark;
      default:
        return AppTheme.greenDark;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning;
      case 'success':
        return Icons.check_circle;
      case 'info':
        return Icons.info;
      case 'error':
        return Icons.error;
      default:
        return Icons.notifications;
    }
  }
}
