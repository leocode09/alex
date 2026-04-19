import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/admin_auth_provider.dart';
import '../../../services/cloud/firestore_paths.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_section_header.dart';
import 'widgets/admin_feature_controls.dart';
import 'widgets/admin_usage_chart.dart';

class AdminDeviceDetailPage extends ConsumerWidget {
  final String installId;
  const AdminDeviceDetailPage({super.key, required this.installId});

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
          'Device details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db
            .collection(FirestorePaths.devicesCollection)
            .doc(installId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data?.data();
          if (data == null) {
            return const Center(child: Text('Device not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(AppTokens.space3),
            children: [
              _Header(installId: installId, data: data),
              const SizedBox(height: AppTokens.space3),
              const AppSectionHeader(title: 'Per-device overrides'),
              AdminFeatureControls(
                target: AdminFeatureTarget.device(installId: installId),
                data: data,
              ),
              const SizedBox(height: AppTokens.space3),
              const AppSectionHeader(title: 'Usage (last 14 days)'),
              AdminUsageChart(
                stream: db
                    .collection(FirestorePaths.devicesCollection)
                    .doc(installId)
                    .collection(FirestorePaths.usageDailySubcollection)
                    .orderBy('day', descending: true)
                    .limit(14)
                    .snapshots(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String installId;
  final Map<String, dynamic> data;
  const _Header({required this.installId, required this.data});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final name = (data['deviceName'] as String?)?.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : installId.substring(0, 8);
    final meta = <String>[
      if (data['shopName'] is String) data['shopName'] as String,
      if (data['platform'] is String) data['platform'] as String,
      if (data['osVersion'] is String) data['osVersion'] as String,
      if (data['model'] is String) data['model'] as String,
      if (data['appVersion'] is String) 'v${data['appVersion']}',
    ];
    return AppPanel(
      emphasized: true,
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            installId,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: extras.muted,
                  fontFamily: 'IBMPlexMono',
                ),
          ),
          const SizedBox(height: AppTokens.space2),
          Text(
            meta.join('  ·  '),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: extras.muted,
                ),
          ),
        ],
      ),
    );
  }
}
