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
import '../../design_system/widgets/app_search_field.dart';
import 'admin_heuristics.dart';
import 'widgets/admin_empty_state.dart';
import 'widgets/admin_skeleton_list.dart';
import 'widgets/admin_status_badge.dart';

/// Filters applied to the shops list. Wired to the filter-chip row.
enum _ShopFilter { all, active, disabled, expiringSoon, expired }

/// Sort options exposed in the overflow menu.
enum _ShopSort { name, devices, revenue7d }

class AdminShopsPage extends ConsumerStatefulWidget {
  /// Optional initial filter (comes from query param, e.g. from the
  /// alerts banner). Maps `expiring`, `disabled`, `expired`, `active`.
  final _ShopFilter? initialFilter;

  const AdminShopsPage({super.key, this.initialFilter});

  /// Parse the query-param flavour that routes use.
  static AdminShopsPage withQueryFilter(String? raw) {
    switch (raw) {
      case 'active':
        return const AdminShopsPage(initialFilter: _ShopFilter.active);
      case 'disabled':
        return const AdminShopsPage(initialFilter: _ShopFilter.disabled);
      case 'expiring':
      case 'expiringSoon':
        return const AdminShopsPage(initialFilter: _ShopFilter.expiringSoon);
      case 'expired':
        return const AdminShopsPage(initialFilter: _ShopFilter.expired);
      default:
        return const AdminShopsPage();
    }
  }

  @override
  ConsumerState<AdminShopsPage> createState() => _AdminShopsPageState();
}

class _AdminShopsPageState extends ConsumerState<AdminShopsPage> {
  final _searchController = TextEditingController();
  String _query = '';
  late _ShopFilter _filter = widget.initialFilter ?? _ShopFilter.all;
  _ShopSort _sort = _ShopSort.name;

  /// Cached per-shop "revenue last 7 days" so the sort doesn't flicker
  /// while the subcollection streams warm up. Lazily populated.
  final Map<String, int> _revenue7dCentsByShop = {};
  final Map<String, int> _deviceCountByShop = {};

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
        const SizedBox(height: AppTokens.space1),
        _FilterRow(
          value: _filter,
          onChanged: (f) => setState(() => _filter = f),
          sort: _sort,
          onSortChanged: (s) => setState(() => _sort = s),
        ),
        const SizedBox(height: AppTokens.space1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection(FirestorePaths.shopsCollection).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const AdminSkeletonList();
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final all = snap.data?.docs ?? const [];
              final docs = all.where((d) => _matches(d.data())).toList();

              // Refresh caches used for sort stability. The side-stream
              // fill happens per-shop inside the tile, so here we just
              // make sure our map has entries for known shops.
              for (final d in all) {
                _revenue7dCentsByShop.putIfAbsent(d.id, () => 0);
                _deviceCountByShop.putIfAbsent(d.id, () => 0);
              }

              docs.sort(_compareByCurrentSort);

              if (docs.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: [
                      AdminEmptyState(
                        icon: Icons.storefront_outlined,
                        title: 'No shops match',
                        subtitle: _query.isNotEmpty || _filter != _ShopFilter.all
                            ? 'Try clearing your filters.'
                            : 'Shops appear once a device creates or joins one.',
                        actionLabel: (_query.isNotEmpty ||
                                _filter != _ShopFilter.all)
                            ? 'Clear filters'
                            : null,
                        onAction: (_query.isNotEmpty ||
                                _filter != _ShopFilter.all)
                            ? () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _filter = _ShopFilter.all;
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTokens.space1),
                  itemBuilder: (context, i) => _ShopTile(
                    doc: docs[i],
                    onRevenue: (cents) =>
                        _revenue7dCentsByShop[docs[i].id] = cents,
                    onDeviceCount: (n) =>
                        _deviceCountByShop[docs[i].id] = n,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    // Streams are live; we just force a rebuild so the user sees a
    // fresh loading pulse if they pull.
    if (mounted) setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  bool _matches(Map<String, dynamic> data) {
    if (_query.isNotEmpty) {
      final name = (data['name'] as String?)?.toLowerCase() ?? '';
      final code = (data['code'] as String?)?.toLowerCase() ?? '';
      if (!name.contains(_query) && !code.contains(_query)) {
        return false;
      }
    }
    final status = AdminHeuristics.shopStatus(data);
    switch (_filter) {
      case _ShopFilter.all:
        return true;
      case _ShopFilter.active:
        return status == ShopStatus.active;
      case _ShopFilter.disabled:
        return status == ShopStatus.disabled;
      case _ShopFilter.expiringSoon:
        return status == ShopStatus.expiringSoon;
      case _ShopFilter.expired:
        return status == ShopStatus.expired;
    }
  }

  int _compareByCurrentSort(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    switch (_sort) {
      case _ShopSort.name:
        final an = (a.data()['name'] as String?)?.toLowerCase() ?? '';
        final bn = (b.data()['name'] as String?)?.toLowerCase() ?? '';
        return an.compareTo(bn);
      case _ShopSort.devices:
        final ac = _deviceCountByShop[a.id] ?? 0;
        final bc = _deviceCountByShop[b.id] ?? 0;
        return bc.compareTo(ac);
      case _ShopSort.revenue7d:
        final ar = _revenue7dCentsByShop[a.id] ?? 0;
        final br = _revenue7dCentsByShop[b.id] ?? 0;
        return br.compareTo(ar);
    }
  }
}

class _FilterRow extends StatelessWidget {
  final _ShopFilter value;
  final ValueChanged<_ShopFilter> onChanged;
  final _ShopSort sort;
  final ValueChanged<_ShopSort> onSortChanged;

  const _FilterRow({
    required this.value,
    required this.onChanged,
    required this.sort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All', _ShopFilter.all),
          _chip('Active', _ShopFilter.active),
          _chip('Expiring', _ShopFilter.expiringSoon),
          _chip('Expired', _ShopFilter.expired),
          _chip('Disabled', _ShopFilter.disabled),
          const SizedBox(width: AppTokens.space2),
          PopupMenuButton<_ShopSort>(
            tooltip: 'Sort',
            initialValue: sort,
            onSelected: onSortChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(value: _ShopSort.name, child: Text('Sort: Name')),
              PopupMenuItem(
                  value: _ShopSort.devices, child: Text('Sort: Devices')),
              PopupMenuItem(
                  value: _ShopSort.revenue7d,
                  child: Text('Sort: Revenue (7d)')),
            ],
            child: Chip(
              avatar: const Icon(Icons.sort, size: 16),
              label: Text(_sortLabel(sort)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _ShopFilter f) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: value == f,
        onSelected: (_) => onChanged(f),
      ),
    );
  }

  static String _sortLabel(_ShopSort s) {
    switch (s) {
      case _ShopSort.name:
        return 'Name';
      case _ShopSort.devices:
        return 'Devices';
      case _ShopSort.revenue7d:
        return 'Revenue (7d)';
    }
  }
}

class _ShopTile extends ConsumerWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final ValueChanged<int> onRevenue;
  final ValueChanged<int> onDeviceCount;

  const _ShopTile({
    required this.doc,
    required this.onRevenue,
    required this.onDeviceCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = doc.data();
    final extras = context.appExtras;
    final name = (data['name'] as String?) ?? 'Shop';
    final code = (data['code'] as String?) ?? '';
    final db = ref.watch(adminAuthServiceProvider).db!;

    return AppPanel(
      onTap: () => context.push('/admin/shops/${doc.id}'),
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
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space1),
                      AdminStatusBadge(data: data),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (code.isNotEmpty) ...[
                        Text(
                          'Code $code',
                          style: TextStyle(
                            color: extras.muted,
                            fontSize: 12,
                            fontFamily: 'IBMPlexMono',
                          ),
                        ),
                        const SizedBox(width: AppTokens.space2),
                      ],
                      _ShopStreamStats(
                        db: db,
                        shopId: doc.id,
                        onRevenue: onRevenue,
                        onDeviceCount: onDeviceCount,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.space1),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

/// Streams the per-shop 7-day revenue total and the device count.
/// Writes back into the parent's sort caches through callbacks.
class _ShopStreamStats extends StatelessWidget {
  final FirebaseFirestore db;
  final String shopId;
  final ValueChanged<int> onRevenue;
  final ValueChanged<int> onDeviceCount;

  const _ShopStreamStats({
    required this.db,
    required this.shopId,
    required this.onRevenue,
    required this.onDeviceCount,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final muted = TextStyle(color: extras.muted, fontSize: 12);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection(FirestorePaths.devicesCollection)
          .where('shopId', isEqualTo: shopId)
          .snapshots(),
      builder: (context, devicesSnap) {
        final deviceCount = devicesSnap.data?.docs.length ?? 0;
        onDeviceCount(deviceCount);
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db
              .collection(FirestorePaths.shopsCollection)
              .doc(shopId)
              .collection(FirestorePaths.usageDailySubcollection)
              .orderBy('day', descending: true)
              .limit(7)
              .snapshots(),
          builder: (context, usageSnap) {
            var cents = 0;
            for (final d in (usageSnap.data?.docs ?? const [])) {
              final v = d.data()[UsageRecorder.kSalesAmountCents];
              if (v is num) cents += v.toInt();
            }
            onRevenue(cents);
            final revenue = AdminHeuristics.fmtMoneyFromCents(cents);
            return Text(
              '$deviceCount device(s)  \u00B7  $revenue (7d)',
              style: muted,
            );
          },
        );
      },
    );
  }
}
