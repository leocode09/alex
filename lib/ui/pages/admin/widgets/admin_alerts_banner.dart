import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../providers/admin_auth_provider.dart';
import '../../../../services/cloud/firestore_paths.dart';
import '../../../design_system/app_theme_extensions.dart';
import '../../../design_system/app_tokens.dart';
import '../../../design_system/widgets/app_panel.dart';
import '../admin_heuristics.dart';

/// Surface fleet-wide issues that need attention: shops with licenses
/// expiring soon, devices that haven't been seen in a while, and
/// devices running an outdated app version.
///
/// Each row links into the relevant filtered list so the admin can
/// act on it with one tap. Rows with zero matches are hidden.
class AdminAlertsBanner extends ConsumerWidget {
  const AdminAlertsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(adminAuthServiceProvider).db;
    if (db == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection(FirestorePaths.shopsCollection).snapshots(),
      builder: (context, shopsSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection(FirestorePaths.devicesCollection).snapshots(),
          builder: (context, devicesSnap) {
            final shops = shopsSnap.data?.docs ?? const [];
            final devices = devicesSnap.data?.docs ?? const [];

            final expiringShops = shops.where(
              (s) =>
                  AdminHeuristics.shopStatus(s.data()) == ShopStatus.expiringSoon ||
                  AdminHeuristics.shopStatus(s.data()) == ShopStatus.expired,
            ).length;

            final offlineDevices = devices.where(
              (d) =>
                  AdminHeuristics.deviceStatus(d.data()) == DeviceStatus.offline,
            ).length;

            final maxVersion =
                AdminHeuristics.maxAppVersion(devices.map((d) => d.data()));
            final outdatedDevices = maxVersion == null
                ? 0
                : devices.where((d) {
                    final v = d.data()['appVersion'] as String?;
                    return v != null &&
                        v.isNotEmpty &&
                        AdminHeuristics.compareAppVersions(v, maxVersion) < 0;
                  }).length;

            final hasAny = expiringShops > 0 ||
                offlineDevices > 0 ||
                outdatedDevices > 0;
            if (!hasAny) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (expiringShops > 0)
                  _AlertRow(
                    tone: Theme.of(context).colorScheme.error,
                    icon: Icons.timer,
                    title: '$expiringShops shop(s) expiring or expired',
                    subtitle: 'License window closes in \u22647 days',
                    onTap: () => context.push(
                      '/admin/shops?filter=expiring',
                    ),
                  ),
                if (offlineDevices > 0)
                  _AlertRow(
                    tone: context.appExtras.warning,
                    icon: Icons.cloud_off,
                    title: '$offlineDevices device(s) offline >3d',
                    subtitle: 'Not heard from in three or more days',
                    onTap: () => context.push(
                      '/admin/devices?filter=offline',
                    ),
                  ),
                if (outdatedDevices > 0)
                  _AlertRow(
                    tone: context.appExtras.warning,
                    icon: Icons.system_update,
                    title: '$outdatedDevices device(s) outdated',
                    subtitle: 'Running an older app version than the fleet',
                    onTap: () => context.push(
                      '/admin/devices?filter=outdated',
                    ),
                  ),
                const SizedBox(height: AppTokens.space2),
              ],
            );
          },
        );
      },
    );
  }
}

class _AlertRow extends StatelessWidget {
  final Color tone;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AlertRow({
    required this.tone,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppTokens.space1),
      color: tone.withValues(alpha: 0.06),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: tone, size: 22),
          const SizedBox(width: AppTokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: extras.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
