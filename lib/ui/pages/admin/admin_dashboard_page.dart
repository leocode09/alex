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
import 'widgets/admin_alerts_banner.dart';
import 'widgets/admin_audit_log_list.dart';
import 'widgets/admin_stat_card.dart';
import 'widgets/admin_status_badge.dart';

/// Top-level admin landing page. Reorganises the fleet overview around
/// three questions: "what needs my attention?" (alerts), "how are we
/// doing?" (stats + top shops), "what has recently changed?" (audit feed).
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(adminAuthServiceProvider).db;
    if (db == null) {
      return const Center(child: Text('Admin is not signed in.'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Streams are live; a tiny delay gives the user a visible
        // refresh feedback.
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const AdminAlertsBanner(),
          const AppSectionHeader(title: 'Fleet overview'),
          _StatsGrid(db: db),
          const SizedBox(height: AppTokens.space3),
          const AppSectionHeader(title: 'Top shops by 7d revenue'),
          _TopShops(db: db),
          const SizedBox(height: AppTokens.space3),
          const AppSectionHeader(title: 'Recently active devices'),
          _RecentDevicesList(db: db),
          const SizedBox(height: AppTokens.space3),
          const AppSectionHeader(title: 'Recent admin changes'),
          const AdminAuditLogList(scope: AdminAuditScope.global, limit: 10),
          const SizedBox(height: AppTokens.space4),
        ],
      ),
    );
  }
}

// =========================================================================
// Stats grid
// =========================================================================

class _StatsGrid extends StatelessWidget {
  final FirebaseFirestore db;
  const _StatsGrid({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection(FirestorePaths.devicesCollection).snapshots(),
      builder: (context, devicesSnap) {
        final devices = devicesSnap.data?.docs ?? const [];
        final activeDay = devices.where((d) {
          final st = AdminHeuristics.deviceStatus(d.data());
          if (st == DeviceStatus.blocked) return false;
          final seen = AdminHeuristics.parseTs(d.data()['lastSeenAtIso']);
          if (seen == null) return false;
          return DateTime.now().difference(seen) <= const Duration(days: 1);
        }).length;
        final activeWeek = devices.where((d) {
          final seen = AdminHeuristics.parseTs(d.data()['lastSeenAtIso']);
          if (seen == null) return false;
          return DateTime.now().difference(seen) <= const Duration(days: 7);
        }).length;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection(FirestorePaths.shopsCollection).snapshots(),
          builder: (context, shopsSnap) {
            final shops = shopsSnap.data?.docs ?? const [];
            return _FleetRevenueTiles(
              db: db,
              deviceCount: devices.length,
              shopCount: shops.length,
              activeDay: activeDay,
              activeWeek: activeWeek,
            );
          },
        );
      },
    );
  }
}

/// Aggregates revenue across every shop's `usageDaily` collection for
/// today and the last 7 days. We use a collectionGroup query so we
/// don't have to fan out per shop.
class _FleetRevenueTiles extends StatelessWidget {
  final FirebaseFirestore db;
  final int deviceCount;
  final int shopCount;
  final int activeDay;
  final int activeWeek;

  const _FleetRevenueTiles({
    required this.db,
    required this.deviceCount,
    required this.shopCount,
    required this.activeDay,
    required this.activeWeek,
  });

  @override
  Widget build(BuildContext context) {
    final today = AdminHeuristics.fmtDate(DateTime.now());
    final sevenDaysAgo = AdminHeuristics.fmtDate(
      DateTime.now().subtract(const Duration(days: 6)),
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collectionGroup(FirestorePaths.usageDailySubcollection)
          .where('day', isGreaterThanOrEqualTo: sevenDaysAgo)
          .snapshots(),
      builder: (context, snap) {
        var revenueTodayCents = 0;
        var revenue7dCents = 0;
        for (final d in (snap.data?.docs ?? const [])) {
          final data = d.data();
          // We only sum from shop-scoped docs — the device-scoped ones
          // would double-count revenue. Presence of a `shopId` field
          // *without* an `installId` field identifies a shop doc.
          if (data['shopId'] == null) continue;
          if (data['installId'] != null) continue;
          final cents = _asInt(data[UsageRecorder.kSalesAmountCents]);
          revenue7dCents += cents;
          if (data['day'] == today) {
            revenueTodayCents += cents;
          }
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppTokens.space2,
          crossAxisSpacing: AppTokens.space2,
          childAspectRatio: 1.55,
          children: [
            AdminStatCard(
              label: 'Total devices',
              value: deviceCount.toString(),
              icon: Icons.devices,
              subtitle: 'across the fleet',
            ),
            AdminStatCard(
              label: 'Active 24h',
              value: activeDay.toString(),
              icon: Icons.wifi_tethering,
              subtitle: 'devices seen today',
              tone: Theme.of(context).colorScheme.primary,
            ),
            AdminStatCard(
              label: 'Active 7d',
              value: activeWeek.toString(),
              icon: Icons.timeline,
              subtitle: 'devices seen in last week',
            ),
            AdminStatCard(
              label: 'Shops',
              value: shopCount.toString(),
              icon: Icons.storefront,
              subtitle: 'tenants provisioned',
              onTap: () => Navigator.of(context).pop(),
            ),
            AdminStatCard(
              label: 'Revenue today',
              value: AdminHeuristics.fmtMoneyFromCents(revenueTodayCents),
              icon: Icons.payments,
              subtitle: 'across all shops',
              tone: context.appExtras.success,
            ),
            AdminStatCard(
              label: 'Revenue 7d',
              value: AdminHeuristics.fmtMoneyFromCents(revenue7dCents),
              icon: Icons.insights,
              subtitle: 'sum of last 7 daily docs',
            ),
          ],
        );
      },
    );
  }

  static int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

// =========================================================================
// Top shops
// =========================================================================

class _TopShops extends StatelessWidget {
  final FirebaseFirestore db;
  const _TopShops({required this.db});

  @override
  Widget build(BuildContext context) {
    final sevenDaysAgo = AdminHeuristics.fmtDate(
      DateTime.now().subtract(const Duration(days: 6)),
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collectionGroup(FirestorePaths.usageDailySubcollection)
          .where('day', isGreaterThanOrEqualTo: sevenDaysAgo)
          .snapshots(),
      builder: (context, snap) {
        // Aggregate revenue cents per shopId.
        final perShop = <String, int>{};
        for (final d in (snap.data?.docs ?? const [])) {
          final data = d.data();
          if (data['shopId'] == null) continue;
          if (data['installId'] != null) continue;
          final shopId = data['shopId'] as String;
          final cents = data[UsageRecorder.kSalesAmountCents];
          if (cents is! num) continue;
          perShop[shopId] = (perShop[shopId] ?? 0) + cents.toInt();
        }
        final ranked = perShop.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top = ranked.take(5).toList();

        if (top.isEmpty) {
          return const AppPanel(
            child: Text('No revenue has been recorded in the last 7 days.'),
          );
        }
        return Column(
          children: [
            for (final e in top)
              _TopShopTile(
                db: db,
                shopId: e.key,
                revenueCents: e.value,
                maxCents: top.first.value,
              ),
          ],
        );
      },
    );
  }
}

class _TopShopTile extends StatelessWidget {
  final FirebaseFirestore db;
  final String shopId;
  final int revenueCents;
  final int maxCents;

  const _TopShopTile({
    required this.db,
    required this.shopId,
    required this.revenueCents,
    required this.maxCents,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final fraction = maxCents == 0 ? 0.0 : revenueCents / maxCents;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db
          .collection(FirestorePaths.shopsCollection)
          .doc(shopId)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final name = (data?['name'] as String?) ?? shopId.substring(0, 8);
        final code = (data?['code'] as String?) ?? '';
        return AppPanel(
          margin: const EdgeInsets.only(bottom: AppTokens.space1),
          onTap: () => context.push('/admin/shops/$shopId'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space2,
              vertical: AppTokens.space2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AdminHeuristics.fmtMoneyFromCents(revenueCents),
                      style: TextStyle(
                        color: extras.success,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'IBMPlexMono',
                      ),
                    ),
                  ],
                ),
                if (code.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Code $code',
                    style: TextStyle(
                      color: extras.muted,
                      fontSize: 12,
                      fontFamily: 'IBMPlexMono',
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusS),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: extras.panelAlt,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =========================================================================
// Recent devices
// =========================================================================

class _RecentDevicesList extends StatelessWidget {
  final FirebaseFirestore db;
  const _RecentDevicesList({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection(FirestorePaths.devicesCollection)
          .orderBy('lastSeenAtIso', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppTokens.space3),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return AppPanel(child: Text('Error: ${snap.error}'));
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const AppPanel(
            child: Text('No devices have reported in yet.'),
          );
        }
        final maxVersion =
            AdminHeuristics.maxAppVersion(docs.map((d) => d.data()));
        return Column(
          children: [
            for (final d in docs)
              _DeviceTile(
                installId: d.id,
                data: d.data(),
                maxVersion: maxVersion,
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
  final String? maxVersion;

  const _DeviceTile({
    required this.installId,
    required this.data,
    required this.maxVersion,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final name = (data['deviceName'] as String?)?.trim();
    final displayName =
        (name != null && name.isNotEmpty) ? name : installId.substring(0, 8);
    final shopName = data['shopName'] as String?;
    final platform = data['platform'] as String?;
    final lastSeen = AdminHeuristics.parseTs(data['lastSeenAtIso']);
    final appVersion = data['appVersion'] as String?;
    final outdated = maxVersion != null &&
        appVersion != null &&
        appVersion.isNotEmpty &&
        AdminHeuristics.compareAppVersions(appVersion, maxVersion!) < 0;

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
                      if (shopName != null && shopName.isNotEmpty) shopName,
                      if (platform != null && platform.isNotEmpty) platform,
                      if (appVersion != null && appVersion.isNotEmpty)
                        'v$appVersion',
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
