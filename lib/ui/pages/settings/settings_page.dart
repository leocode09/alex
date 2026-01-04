import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/tax_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('General'),
          _buildSettingTile(
            context,
            'Store Profile',
            'Manage store details and branding',
            Icons.store_outlined,
            onTap: () => context.push('/stores'),
          ),
          _buildSettingTile(
            context,
            'Hardware Setup',
            'Printers, scanners, and terminals',
            Icons.devices_outlined,
            onTap: () => context.push('/hardware'),
          ),
          _buildSettingTile(
            context,
            'Promotions',
            'Discounts and loyalty programs',
            Icons.local_offer_outlined,
            onTap: () => context.push('/promotions'),
          ),
          _buildSettingTile(
            context,
            'Tax Settings',
            'Configure tax rate and calculation',
            Icons.receipt_long_outlined,
            onTap: () => _showTaxSettings(context, ref),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Account & Security'),
          _buildSettingTile(
            context,
            'Employees',
            'Manage staff and permissions',
            Icons.people_outline,
            onTap: () => context.push('/employees'),
          ),
          _buildSettingTile(
            context,
            'Security',
            'PIN, passwords, and access logs',
            Icons.lock_outline,
            onTap: () {},
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('App Preferences'),
          _buildSettingTile(
            context,
            'Language',
            'English (US)',
            Icons.language,
            onTap: () {},
          ),
          _buildSettingTile(
            context,
            'Theme',
            'Light Mode',
            Icons.brightness_6_outlined,
            onTap: () {},
          ),
          _buildSettingTile(
            context,
            'Notifications',
            'Manage alerts and sounds',
            Icons.notifications_outlined,
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Support'),
          _buildSettingTile(
            context,
            'Help Center',
            'FAQ and support contact',
            Icons.help_outline,
            onTap: () {},
          ),
          _buildSettingTile(
            context,
            'About',
            'Version 1.0.0',
            Icons.info_outline,
            onTap: () {},
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Log Out'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading:
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
        subtitle: Text(subtitle,
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  void _showTaxSettings(BuildContext context, WidgetRef ref) {
    final taxSettings = ref.read(taxSettingsProvider);
    final taxRateController = TextEditingController(
      text: (taxSettings.taxRate * 100).toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tax Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tax Rate (%)',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: taxRateController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter tax rate (e.g., 18 for 18%)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                final settings = ref.watch(taxSettingsProvider);
                return SwitchListTile(
                  title: const Text('Include Tax in Sales',
                      style: TextStyle(fontSize: 14)),
                  value: settings.includeTax,
                  onChanged: (value) {
                    ref
                        .read(taxSettingsProvider.notifier)
                        .updateIncludeTax(value);
                  },
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final rateText = taxRateController.text;
              final rate = double.tryParse(rateText);
              if (rate != null && rate >= 0 && rate <= 100) {
                ref
                    .read(taxSettingsProvider.notifier)
                    .updateTaxRate(rate / 100);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tax settings updated')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid tax rate (0-100)')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
