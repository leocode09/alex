import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/license_policy.dart';
import '../../../providers/admin_auth_provider.dart';
import '../../../services/cloud/firestore_paths.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_empty_state.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_search_field.dart';

class AdminShopsPage extends ConsumerStatefulWidget {
  const AdminShopsPage({super.key});

  @override
  ConsumerState<AdminShopsPage> createState() => _AdminShopsPageState();
}

class _AdminShopsPageState extends ConsumerState<AdminShopsPage> {
  final _searchController = TextEditingController();
  String _query = '';

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
          hintText: 'Search by shop name or code',
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        const SizedBox(height: AppTokens.space2),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection(FirestorePaths.shopsCollection).snapshots(),
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
              docs.sort((a, b) {
                final an = (a.data()['name'] as String?)?.toLowerCase() ?? '';
                final bn = (b.data()['name'] as String?)?.toLowerCase() ?? '';
                return an.compareTo(bn);
              });

              if (docs.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No shops yet',
                  subtitle:
                      'Shops appear once a device creates or joins one.',
                );
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppTokens.space1),
                itemBuilder: (context, i) => _ShopTile(doc: docs[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _matches(Map<String, dynamic> data) {
    if (_query.isEmpty) return true;
    final name = (data['name'] as String?)?.toLowerCase() ?? '';
    final code = (data['code'] as String?)?.toLowerCase() ?? '';
    return name.contains(_query) || code.contains(_query);
  }
}

class _ShopTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _ShopTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final extras = context.appExtras;
    final name = (data['name'] as String?) ?? 'Shop';
    final code = (data['code'] as String?) ?? '';
    final enabled = data['enabled'] as bool? ?? true;
    final expiresAt = _parseTs(data['licenseExpiresAt']);
    final memberCount = (data['memberCount'] as num?)?.toInt();

    final tone = enabled && !_isExpired(expiresAt) ? extras.success : extras.danger;

    return AppPanel(
      onTap: () => context.push('/admin/shops/${doc.id}'),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppTokens.space2),
        leading: CircleAvatar(
          backgroundColor: tone.withValues(alpha: 0.15),
          child: Icon(Icons.storefront, color: tone),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (code.isNotEmpty) 'Code $code',
            if (memberCount != null) '$memberCount device(s)',
            _licenseSummary(enabled, expiresAt),
          ].where((s) => s.isNotEmpty).join('  ·  '),
          style: TextStyle(color: extras.muted, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  static bool _isExpired(DateTime? at) =>
      at != null && DateTime.now().isAfter(at);

  static String _licenseSummary(bool enabled, DateTime? expiresAt) {
    if (!enabled) return 'Disabled';
    if (expiresAt == null) return 'Active';
    if (_isExpired(expiresAt)) return 'Expired';
    return 'Expires ${_fmt(expiresAt)}';
  }

  static DateTime? _parseTs(dynamic raw) =>
      LicensePolicy.fromDocs(shop: {'licenseExpiresAt': raw})
          .effectiveExpiresAt;

  static String _fmt(DateTime at) =>
      '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
}
