import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/admin_auth_provider.dart';
import '../../../services/admin/usage_recorder.dart';
import '../../../services/cloud/firestore_paths.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_section_header.dart';
import 'admin_heuristics.dart';
import 'widgets/admin_audit_log_list.dart';
import 'widgets/admin_feature_controls.dart';
import 'widgets/admin_quick_actions.dart';
import 'widgets/admin_status_badge.dart';
import 'widgets/admin_usage_chart.dart';

/// Full-page editor for a single shop's license + feature flags.
class AdminShopDetailPage extends ConsumerWidget {
  final String shopId;

  const AdminShopDetailPage({super.key, required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(adminAuthServiceProvider).db;
    if (db == null) {
      return const Scaffold(
        body: Center(child: Text('Admin is not signed in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shop details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db
            .collection(FirestorePaths.shopsCollection)
            .doc(shopId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final data = snap.data?.data();
          if (data == null) {
            return const Center(child: Text('Shop not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(AppTokens.space3),
            children: [
              _Header(shopId: shopId, data: data, db: db),
              const SizedBox(height: AppTokens.space3),
              AdminQuickActions(
                target: AdminQuickTarget.shop,
                targetId: shopId,
                data: data,
              ),
              const SizedBox(height: AppTokens.space3),
              const AppSectionHeader(title: 'License & lifecycle'),
              AdminFeatureControls(
                target: AdminFeatureTarget.shop(shopId: shopId),
                data: data,
              ),
              const SizedBox(height: AppTokens.space3),
              const AppSectionHeader(title: 'Usage (last 14 days)'),
              AdminUsageChart(
                showMetricPicker: true,
                stream: db
                    .collection(FirestorePaths.shopsCollection)
                    .doc(shopId)
                    .collection(FirestorePaths.usageDailySubcollection)
                    .orderBy('day', descending: true)
                    .limit(14)
                    .snapshots(),
              ),
              const SizedBox(height: AppTokens.space3),
              const AppSectionHeader(title: 'Member devices'),
              _ShopDevicesList(db: db, shopId: shopId),
              const SizedBox(height: AppTokens.space3),
              const AppSectionHeader(title: 'Activity'),
              AdminAuditLogList(
                scope: AdminAuditScope.shop,
                targetId: shopId,
              ),
              const SizedBox(height: AppTokens.space4),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String shopId;
  final Map<String, dynamic> data;
  final FirebaseFirestore db;
  const _Header({
    required this.shopId,
    required this.data,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final name = (data['name'] as String?) ?? 'Shop';
    final code = (data['code'] as String?) ?? '';

    return AppPanel(
      emphasized: true,
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code $code  \u00B7  id $shopId',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: extras.muted,
                                fontFamily: 'IBMPlexMono',
                              ),
                    ),
                  ],
                ),
              ),
              AdminStatusBadge(data: data),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          _HeaderStats(db: db, shopId: shopId),
        ],
      ),
    );
  }
}

class _HeaderStats extends StatelessWidget {
  final FirebaseFirestore db;
  final String shopId;

  const _HeaderStats({required this.db, required this.shopId});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final today = AdminHeuristics.fmtDate(DateTime.now());

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection(FirestorePaths.devicesCollection)
          .where('shopId', isEqualTo: shopId)
          .snapshots(),
      builder: (context, devicesSnap) {
        final devices = devicesSnap.data?.docs ?? const [];
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: db
              .collection(FirestorePaths.shopsCollection)
              .doc(shopId)
              .collection(FirestorePaths.usageDailySubcollection)
              .doc(today)
              .snapshots(),
          builder: (context, todaySnap) {
            final todayData = todaySnap.data?.data();
            final salesToday = _asInt(
              todayData?[UsageRecorder.kSalesCount],
            );
            final revenueCents = _asInt(
              todayData?[UsageRecorder.kSalesAmountCents],
            );
            return Row(
              children: [
                _stat(context, 'Devices', devices.length.toString(),
                    Icons.phone_android),
                const SizedBox(width: AppTokens.space3),
                _stat(
                  context,
                  'Sales today',
                  salesToday.toString(),
                  Icons.point_of_sale,
                ),
                const SizedBox(width: AppTokens.space3),
                _stat(
                  context,
                  'Revenue today',
                  AdminHeuristics.fmtMoneyFromCents(revenueCents),
                  Icons.payments,
                  color: extras.success,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final extras = context.appExtras;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color ?? extras.muted),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: extras.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color ?? Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontFamily: 'IBMPlexMono',
            ),
          ),
        ],
      ),
    );
  }

  static int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class _ShopDevicesList extends StatelessWidget {
  final FirebaseFirestore db;
  final String shopId;
  const _ShopDevicesList({required this.db, required this.shopId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection(FirestorePaths.devicesCollection)
          .where('shopId', isEqualTo: shopId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppTokens.space2),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const AppPanel(
            child: Text('No devices are currently attached to this shop.'),
          );
        }
        final maxVersion =
            AdminHeuristics.maxAppVersion(docs.map((d) => d.data()));
        return Column(
          children: docs
              .map((d) => _ShopDeviceTile(
                    installId: d.id,
                    data: d.data(),
                    maxVersion: maxVersion,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _ShopDeviceTile extends StatelessWidget {
  final String installId;
  final Map<String, dynamic> data;
  final String? maxVersion;

  const _ShopDeviceTile({
    required this.installId,
    required this.data,
    required this.maxVersion,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final name = (data['deviceName'] as String?)?.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : installId.substring(0, 8);
    final appVersion = data['appVersion'] as String?;
    final outdated = maxVersion != null &&
        appVersion != null &&
        appVersion.isNotEmpty &&
        AdminHeuristics.compareAppVersions(appVersion, maxVersion!) < 0;
    final lastSeen = AdminHeuristics.parseTs(data['lastSeenAtIso']);

    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppTokens.space1),
      onTap: () => context.push('/admin/devices/$installId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space2,
          vertical: AppTokens.space2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AdminStatusBadge(
                        data: data,
                        isDevice: true,
                        outdated: outdated,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      data['platform'] as String? ?? 'unknown',
                      if (appVersion != null) 'v$appVersion',
                      if (lastSeen != null)
                        'seen ${AdminHeuristics.relativeShort(lastSeen)}',
                    ].join('  \u00B7  '),
                    style: TextStyle(color: extras.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
