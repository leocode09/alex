import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/admin_auth_provider.dart';
import '../../../services/cloud/firestore_paths.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_empty_state.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_search_field.dart';

class AdminDevicesPage extends ConsumerStatefulWidget {
  const AdminDevicesPage({super.key});

  @override
  ConsumerState<AdminDevicesPage> createState() => _AdminDevicesPageState();
}

class _AdminDevicesPageState extends ConsumerState<AdminDevicesPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _onlyBlocked = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(adminAuthServiceProvider).db;
    if (db == null) {
      return const Center(child: Text('Admin is not signed in.'));
    }
    return Column(
      children: [
        AppSearchField(
          controller: _searchController,
          hintText: 'Search by device name, shop or platform',
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        const SizedBox(height: AppTokens.space1),
        Row(
          children: [
            FilterChip(
              label: const Text('Only blocked'),
              selected: _onlyBlocked,
              onSelected: (v) => setState(() => _onlyBlocked = v),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection(FirestorePaths.devicesCollection)
                .orderBy('lastSeenAtIso', descending: true)
                .limit(500)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final docs = (snap.data?.docs ?? const [])
                  .where((d) => _matches(d.data()))
                  .toList();
              if (docs.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.devices_other_outlined,
                  title: 'No devices match',
                );
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppTokens.space1),
                itemBuilder: (context, i) => _DeviceTile(
                  installId: docs[i].id,
                  data: docs[i].data(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _matches(Map<String, dynamic> data) {
    if (_onlyBlocked && data['blocked'] != true) {
      return false;
    }
    if (_query.isEmpty) {
      return true;
    }
    final hay = [
      data['deviceName'],
      data['shopName'],
      data['platform'],
      data['model'],
      data['appVersion'],
    ].whereType<String>().join(' ').toLowerCase();
    return hay.contains(_query);
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
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : installId.substring(0, 8);
    final shopName = data['shopName'] as String?;
    final platform = data['platform'] as String?;
    final lastSeen = data['lastSeenAtIso'] as String?;
    final blocked = data['blocked'] as bool? ?? false;

    return AppPanel(
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
            if (shopName != null && shopName.isNotEmpty) shopName,
            if (platform != null && platform.isNotEmpty) platform,
            if (lastSeen != null)
              'Last seen ${lastSeen.substring(0, 16).replaceFirst("T", " ")}',
            if (blocked) 'BLOCKED',
          ].join('  ·  '),
          style: TextStyle(color: extras.muted, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
