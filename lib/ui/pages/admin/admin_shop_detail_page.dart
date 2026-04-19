import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/license_policy.dart';
import '../../../providers/admin_auth_provider.dart';
import '../../../services/cloud/firestore_paths.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_section_header.dart';
import 'widgets/admin_feature_controls.dart';
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
              _Header(shopId: shopId, data: data),
              const SizedBox(height: AppTokens.space3),
              const AppSectionHeader(title: 'License & lifecycle'),
              AdminFeatureControls(
                target: AdminFeatureTarget.shop(shopId: shopId),
                data: data,
              ),
              const SizedBox(height: AppTokens.space3),
              const AppSectionHeader(title: 'Usage (last 14 days)'),
              AdminUsageChart(
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
  const _Header({required this.shopId, required this.data});

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
          Text(
            name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Code $code · id $shopId',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: extras.muted,
                  fontFamily: 'IBMPlexMono',
                ),
          ),
        ],
      ),
    );
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
        return Column(
          children: docs
              .map((d) => _ShopDeviceTile(
                    installId: d.id,
                    data: d.data(),
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
  const _ShopDeviceTile({required this.installId, required this.data});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final name = (data['deviceName'] as String?)?.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : installId.substring(0, 8);
    final blocked = data['blocked'] as bool? ?? false;
    final expiresAt = LicensePolicy.fromDocs(device: {'expiresAt': data['expiresAt']})
        .deviceExpiresAt;
    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppTokens.space1),
      onTap: () => context.push('/admin/devices/$installId'),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppTokens.space2),
        leading: Icon(
          blocked ? Icons.block : Icons.phone_android,
          color: blocked ? extras.danger : null,
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            data['platform'] as String? ?? 'unknown',
            if (data['appVersion'] != null) 'v${data['appVersion']}',
            if (expiresAt != null)
              'expires ${expiresAt.toIso8601String().substring(0, 10)}',
            if (blocked) 'BLOCKED',
          ].join('  ·  '),
          style: TextStyle(color: extras.muted, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
