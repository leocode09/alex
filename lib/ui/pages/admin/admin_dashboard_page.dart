import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/admin_auth_provider.dart';
import '../../../services/cloud/firestore_paths.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_section_header.dart';
import '../../design_system/widgets/app_stat_tile.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(adminAuthServiceProvider).db;
    if (db == null) {
      return const Center(
        child: Text('Admin is not signed in.'),
      );
    }

    return ListView(
      children: [
        const AppSectionHeader(title: 'Fleet overview'),
        _StatsRow(db: db),
        const SizedBox(height: AppTokens.space3),
        const AppSectionHeader(title: 'Recently active devices'),
        _RecentDevicesList(db: db),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final FirebaseFirestore db;
  const _StatsRow({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection(FirestorePaths.devicesCollection).snapshots(),
      builder: (context, devicesSnap) {
        final devices = devicesSnap.data?.docs ?? const [];
        final now = DateTime.now();
        final activeDay = devices.where((d) =>
            _isRecent(d.data()['lastSeenAtIso'], now, const Duration(days: 1)));
        final activeWeek = devices.where((d) => _isRecent(
            d.data()['lastSeenAtIso'], now, const Duration(days: 7)));

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection(FirestorePaths.shopsCollection).snapshots(),
          builder: (context, shopsSnap) {
            final shops = shopsSnap.data?.docs ?? const [];
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: AppTokens.space2,
              crossAxisSpacing: AppTokens.space2,
              childAspectRatio: 2.2,
              children: [
                AppStatTile(
                  label: 'Total devices',
                  value: devices.length.toString(),
                  icon: Icons.devices,
                ),
                AppStatTile(
                  label: 'Active (24h)',
                  value: activeDay.length.toString(),
                  icon: Icons.wifi_tethering,
                ),
                AppStatTile(
                  label: 'Active (7d)',
                  value: activeWeek.length.toString(),
                  icon: Icons.show_chart,
                ),
                AppStatTile(
                  label: 'Shops',
                  value: shops.length.toString(),
                  icon: Icons.storefront,
                ),
              ],
            );
          },
        );
      },
    );
  }

  static bool _isRecent(dynamic iso, DateTime now, Duration window) {
    if (iso is! String) return false;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return false;
    return now.difference(dt) <= window;
  }
}

class _RecentDevicesList extends StatelessWidget {
  final FirebaseFirestore db;
  const _RecentDevicesList({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection(FirestorePaths.devicesCollection)
          .orderBy('lastSeenAtIso', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppTokens.space3),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return AppPanel(
            child: Text('Error: ${snap.error}'),
          );
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const AppPanel(
            child: Text('No devices have reported in yet.'),
          );
        }
        return Column(
          children: [
            for (final d in docs)
              _DeviceTile(
                installId: d.id,
                data: d.data(),
              ),
          ],
        );
      },
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final String installId;
  final Map<String, dynamic> data;

  const _DeviceTile({required this.installId, required this.data});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final name = (data['deviceName'] as String?)?.trim();
    final displayName =
        (name != null && name.isNotEmpty) ? name : installId.substring(0, 8);
    final shopName = data['shopName'] as String?;
    final platform = data['platform'] as String?;
    final lastSeen = data['lastSeenAtIso'] as String?;
    final appVersion = data['appVersion'] as String?;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppTokens.space1),
      onTap: () {
        context.push('/admin/devices/$installId');
      },
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppTokens.space2),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (shopName != null && shopName.isNotEmpty) shopName,
            if (platform != null && platform.isNotEmpty) platform,
            if (appVersion != null && appVersion.isNotEmpty) 'v$appVersion',
            if (lastSeen != null && lastSeen.isNotEmpty)
              'Last seen ${_relative(lastSeen)}',
          ].join('  ·  '),
          style: TextStyle(color: extras.muted, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  static String _relative(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}
