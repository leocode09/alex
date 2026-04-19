import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../providers/admin_auth_provider.dart';
import '../../../../services/cloud/firestore_paths.dart';
import '../../../design_system/app_theme_extensions.dart';
import '../../../design_system/app_tokens.dart';
import '../../../design_system/widgets/app_panel.dart';
import '../../../design_system/widgets/app_search_field.dart';
import '../admin_heuristics.dart';
import 'admin_status_badge.dart';

/// Full-screen style modal bottom sheet that searches across shops
/// and devices with a single text query. Results appear live while
/// the admin types.
Future<void> showAdminGlobalSearchSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const SizedBox(
      height: 620,
      child: _AdminGlobalSearchSheet(),
    ),
  );
}

class _AdminGlobalSearchSheet extends ConsumerStatefulWidget {
  const _AdminGlobalSearchSheet();

  @override
  ConsumerState<_AdminGlobalSearchSheet> createState() =>
      _AdminGlobalSearchSheetState();
}

class _AdminGlobalSearchSheetState
    extends ConsumerState<_AdminGlobalSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(adminAuthServiceProvider).db;
    if (db == null) {
      return const Center(child: Text('Admin is not signed in.'));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space3,
        AppTokens.space1,
        AppTokens.space3,
        AppTokens.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchField(
            controller: _controller,
            hintText: 'Search shops and devices',
            onChanged: (v) =>
                setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: AppTokens.space2),
          Expanded(
            child: _query.isEmpty
                ? _HintState()
                : _Results(db: db, query: _query),
          ),
        ],
      ),
    );
  }
}

class _HintState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 36, color: extras.muted),
          const SizedBox(height: 8),
          Text(
            'Type to search by shop name, shop code, device name, platform, or app version.',
            textAlign: TextAlign.center,
            style: TextStyle(color: extras.muted),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  final FirebaseFirestore db;
  final String query;
  const _Results({required this.db, required this.query});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection(FirestorePaths.shopsCollection).snapshots(),
      builder: (context, shopsSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection(FirestorePaths.devicesCollection).snapshots(),
          builder: (context, devicesSnap) {
            final shopMatches = (shopsSnap.data?.docs ?? const [])
                .where((d) => _matchesShop(d.data(), query))
                .toList();
            final deviceMatches = (devicesSnap.data?.docs ?? const [])
                .where((d) => _matchesDevice(d.data(), query))
                .toList();

            if (shopMatches.isEmpty && deviceMatches.isEmpty) {
              return const Center(child: Text('No matches.'));
            }

            return ListView(
              children: [
                if (shopMatches.isNotEmpty) ...[
                  _SectionLabel(
                    label: 'Shops',
                    count: shopMatches.length,
                  ),
                  for (final d in shopMatches.take(10))
                    _ShopResult(id: d.id, data: d.data()),
                  const SizedBox(height: AppTokens.space3),
                ],
                if (deviceMatches.isNotEmpty) ...[
                  _SectionLabel(
                    label: 'Devices',
                    count: deviceMatches.length,
                  ),
                  for (final d in deviceMatches.take(20))
                    _DeviceResult(id: d.id, data: d.data()),
                ],
              ],
            );
          },
        );
      },
    );
  }

  static bool _matchesShop(Map<String, dynamic> d, String q) {
    final name = (d['name'] as String?)?.toLowerCase() ?? '';
    final code = (d['code'] as String?)?.toLowerCase() ?? '';
    return name.contains(q) || code.contains(q);
  }

  static bool _matchesDevice(Map<String, dynamic> d, String q) {
    final hay = [
      d['deviceName'],
      d['shopName'],
      d['platform'],
      d['model'],
      d['appVersion'],
    ].whereType<String>().join(' ').toLowerCase();
    return hay.contains(q);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _SectionLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return Padding(
      padding: const EdgeInsets.only(
        top: AppTokens.space1,
        bottom: AppTokens.space1,
      ),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: extras.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: TextStyle(color: extras.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ShopResult extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  const _ShopResult({required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] as String?) ?? 'Shop';
    final code = (data['code'] as String?) ?? '';
    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppTokens.space1),
      onTap: () {
        Navigator.of(context).pop();
        context.push('/admin/shops/$id');
      },
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppTokens.space2),
        leading: const Icon(Icons.storefront),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Code $code',
          style: TextStyle(color: context.appExtras.muted, fontSize: 12),
        ),
        trailing: AdminStatusBadge(data: data),
      ),
    );
  }
}

class _DeviceResult extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  const _DeviceResult({required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final name = (data['deviceName'] as String?)?.trim();
    final displayName =
        (name != null && name.isNotEmpty) ? name : id.substring(0, 8);
    final shop = data['shopName'] as String?;
    final platform = data['platform'] as String?;
    final version = data['appVersion'] as String?;
    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppTokens.space1),
      onTap: () {
        Navigator.of(context).pop();
        context.push('/admin/devices/$id');
      },
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppTokens.space2),
        leading: const Icon(Icons.phone_android),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (shop != null && shop.isNotEmpty) shop,
            if (platform != null && platform.isNotEmpty) platform,
            if (version != null && version.isNotEmpty) 'v$version',
          ].join('  \u00B7  '),
          style: TextStyle(color: extras.muted, fontSize: 12),
        ),
        trailing: AdminStatusBadge(data: data, isDevice: true),
      ),
    );
  }
}
