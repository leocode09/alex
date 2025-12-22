import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        children: [
          // Quick Access Section
          _buildSection(
            context,
            'Quick Access',
            [
              _buildTile(
                context,
                Icons.inventory_2,
                'Inventory',
                'Manage stock and inventory',
                () => context.push('/inventory'),
              ),
              _buildTile(
                context,
                Icons.people,
                'Customers',
                'View and manage customers',
                () => context.push('/customers'),
              ),
              _buildTile(
                context,
                Icons.badge,
                'Employees',
                'Manage staff and permissions',
                () => context.push('/employees'),
              ),
              _buildTile(
                context,
                Icons.store,
                'Stores',
                'Multi-store management',
                () => context.push('/stores'),
              ),
              _buildTile(
                context,
                Icons.local_offer,
                'Promotions',
                'Discounts and loyalty programs',
                () => context.push('/promotions'),
              ),
              _buildTile(
                context,
                Icons.devices,
                'Hardware Setup',
                'Connect printers and scanners',
                () => context.push('/hardware'),
              ),
              _buildTile(
                context,
                Icons.notifications_active,
                'Notifications',
                'View all notifications',
                () => context.push('/notifications'),
              ),
            ],
          ),
          _buildSection(
            context,
            'Security',
            [
              _buildTile(
                context,
                Icons.lock,
                'Change PIN',
                'Update your security PIN',
                () {
                  // TODO: Implement change PIN
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Change PIN feature')),
                  );
                },
              ),
              _buildTile(
                context,
                Icons.admin_panel_settings,
                'User Permissions',
                'Manage user roles and access',
                () {
                  // TODO: Implement permissions
                },
              ),
            ],
          ),
          _buildSection(
            context,
            'Data Management',
            [
              _buildTile(
                context,
                Icons.backup,
                'Backup & Restore',
                'Backup your data to cloud',
                () {
                  // TODO: Implement backup
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup feature')),
                  );
                },
              ),
              _buildTile(
                context,
                Icons.sync,
                'Sync Data',
                'Sync with other stores',
                () {
                  // TODO: Implement sync
                },
              ),
            ],
          ),
          _buildSection(
            context,
            'Payment Settings',
            [
              _buildTile(
                context,
                Icons.payment,
                'Payment Methods',
                'Configure payment options',
                () {
                  // TODO: Navigate to payment methods
                },
              ),
              _buildTile(
                context,
                Icons.receipt,
                'Receipt Settings',
                'Customize receipt format',
                () {
                  // TODO: Implement receipt settings
                },
              ),
            ],
          ),
          _buildSection(
            context,
            'General',
            [
              _buildTile(
                context,
                Icons.business,
                'Business Information',
                'Update store details',
                () {
                  // TODO: Implement business info
                },
              ),
              _buildTile(
                context,
                Icons.notifications,
                'Notifications',
                'Manage notification preferences',
                () {
                  // TODO: Implement notification settings
                },
              ),
              _buildTile(
                context,
                Icons.language,
                'Language',
                'Change app language',
                () {
                  // TODO: Implement language settings
                },
              ),
            ],
          ),
          _buildSection(
            context,
            'About',
            [
              _buildTile(
                context,
                Icons.info,
                'App Version',
                'Version 1.0.0',
                null,
              ),
              _buildTile(
                context,
                Icons.help,
                'Help & Support',
                'Get help and contact support',
                () {
                  // TODO: Navigate to support
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...tiles,
        const Divider(),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap != null ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
      onTap: onTap,
    );
  }
}
