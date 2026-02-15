import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/pin_unlock_provider.dart';
import '../../../providers/theme_mode_provider.dart';
import '../../../services/database_helper.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return AppPageScaffold(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'General'),
          _buildSettingTile(
            context,
            'Store Profile',
            'Manage store details and branding',
            Icons.store_outlined,
            onTap: () async {
              if (await PinProtection.requirePinIfNeeded(
                context,
                isRequired: () => PinService().isPinRequiredForViewStores(),
                title: 'Stores Access',
                subtitle: 'Enter PIN to view stores',
              )) {
                if (!context.mounted) {
                  return;
                }
                context.push('/stores');
              }
            },
          ),
          _buildSettingTile(
            context,
            'Hardware Setup',
            'Printers, scanners, and terminals',
            Icons.devices_outlined,
            onTap: () async {
              if (await PinProtection.requirePinIfNeeded(
                context,
                isRequired: () => PinService().isPinRequiredForHardwareSetup(),
                title: 'Hardware Setup',
                subtitle: 'Enter PIN to configure hardware',
              )) {
                if (!context.mounted) {
                  return;
                }
                context.push('/hardware');
              }
            },
          ),
          _buildSettingTile(
            context,
            'LAN Manager',
            'Manage Wi-Fi Direct peers and sync',
            Icons.wifi_tethering,
            onTap: () async {
              if (await PinProtection.requirePinIfNeeded(
                context,
                isRequired: () => PinService().isPinRequiredForDataSync(),
                title: 'LAN Manager',
                subtitle: 'Enter PIN to manage LAN',
              )) {
                if (!context.mounted) {
                  return;
                }
                context.push('/lan');
              }
            },
          ),
          _buildSettingTile(
            context,
            'Promotions',
            'Discounts and loyalty programs',
            Icons.local_offer_outlined,
            onTap: () async {
              if (await PinProtection.requirePinIfNeeded(
                context,
                isRequired: () =>
                    PinService().isPinRequiredForManagePromotions(),
                title: 'Promotions',
                subtitle: 'Enter PIN to manage promotions',
              )) {
                if (!context.mounted) {
                  return;
                }
                context.push('/promotions');
              }
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Account & Security'),
          _buildSettingTile(
            context,
            'Employees',
            'Manage staff and permissions',
            Icons.people_outline,
            onTap: () async {
              if (await PinProtection.requirePinIfNeeded(
                context,
                isRequired: () => PinService().isPinRequiredForViewEmployees(),
                title: 'Employees',
                subtitle: 'Enter PIN to view employees',
              )) {
                if (!context.mounted) {
                  return;
                }
                context.push('/employees');
              }
            },
          ),
          _buildSettingTile(
            context,
            'Security',
            'PIN, passwords, and access logs',
            Icons.lock_outline,
            onTap: () => _showSecurityOptions(context),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'App Preferences'),
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
            _themeModeLabel(themeMode),
            Icons.brightness_6_outlined,
            onTap: () => _showThemeOptions(context, ref, themeMode),
          ),
          _buildSettingTile(
            context,
            'Notifications',
            'Manage alerts and sounds',
            Icons.notifications_outlined,
            onTap: () async {
              if (await PinProtection.requirePinIfNeeded(
                context,
                isRequired: () =>
                    PinService().isPinRequiredForViewNotifications(),
                title: 'Notifications',
                subtitle: 'Enter PIN to view notifications',
              )) {
                if (!context.mounted) {
                  return;
                }
                context.push('/notifications');
              }
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Support'),
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
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Data Management'),
          _buildSettingTile(
            context,
            'Clear All Data',
            'Remove all products, sales, and settings',
            Icons.delete_sweep_outlined,
            onTap: () => _showClearDataDialog(context),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () {
              PinService().clearSessionVerified();
              ref.read(pinUnlockedProvider.notifier).state = false;
              context.go('/pin-entry');
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    final muted = context.appExtras.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: muted,
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
    final theme = Theme.of(context);
    final extras = context.appExtras;
    return AppPanel(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: extras.muted,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: extras.muted,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light Mode';
    }
  }

  void _showThemeOptions(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    final textTheme = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Choose Theme',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildThemeModeOption(
                context: sheetContext,
                ref: ref,
                value: ThemeMode.light,
                currentMode: currentMode,
                label: 'Light',
              ),
              _buildThemeModeOption(
                context: sheetContext,
                ref: ref,
                value: ThemeMode.dark,
                currentMode: currentMode,
                label: 'Dark',
              ),
              _buildThemeModeOption(
                context: sheetContext,
                ref: ref,
                value: ThemeMode.system,
                currentMode: currentMode,
                label: 'System default',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeModeOption({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeMode value,
    required ThemeMode currentMode,
    required String label,
  }) {
    final selected = currentMode == value;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () async {
        await ref.read(themeModeProvider.notifier).setThemeMode(value);
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  void _showClearDataDialog(BuildContext context) {
    PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForClearAllData(),
      title: 'Clear All Data',
      subtitle: 'Enter PIN to clear all data',
    ).then((verified) {
      if (!verified) {
        return;
      }
      if (!context.mounted) {
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Clear All Data?'),
            ],
          ),
          content: const Text(
            'This will permanently delete:\n\n'
            '- All products\n'
            '- All sales records\n'
            '- All customers\n'
            '- All settings\n'
            '- Cart data\n\n'
            'This action cannot be undone!',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  final storage = StorageHelper();
                  await storage.clearAll();

                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All data cleared successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Navigate to home to refresh
                    context.go('/');
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error clearing data: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear All Data'),
            ),
          ],
        ),
      );
    });
  }

  void _showSecurityOptions(BuildContext context) {
    final parentContext = context;
    showModalBottomSheet(
      context: parentContext,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('PIN Preferences'),
              subtitle: const Text('Choose where PIN is required'),
              onTap: () {
                Navigator.pop(sheetContext);
                parentContext.push('/pin-preferences');
              },
            ),
            ListTile(
              leading: const Icon(Icons.pin),
              title: const Text('Change PIN'),
              subtitle: const Text('Update your 4-digit PIN'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final verified = await PinProtection.requirePinIfNeeded(
                  parentContext,
                  isRequired: () => PinService().isPinRequiredForChangePin(),
                  title: 'Change PIN',
                  subtitle: 'Enter current PIN to change PIN',
                );
                if (verified && parentContext.mounted) {
                  parentContext.push('/pin-setup?mode=change');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
