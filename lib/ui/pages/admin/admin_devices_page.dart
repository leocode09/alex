import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/admin_auth_provider.dart';
import '../../../services/admin/admin_audit_service.dart';
import '../../../services/cloud/firestore_paths.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_search_field.dart';
import 'admin_heuristics.dart';
import 'widgets/admin_empty_state.dart';
import 'widgets/admin_skeleton_list.dart';
import 'widgets/admin_status_badge.dart';

/// Filters applied to the devices list.
enum _DeviceFilter {
  all,
  online,
  offline,
  blocked,
  expiringSoon,
  outdated,
}

/// Sort options.
enum _DeviceSort { lastSeen, deviceName, appVersion }

class AdminDevicesPage extends ConsumerStatefulWidget {
  /// Optional initial filter (comes from query param).
  final _DeviceFilter? initialFilter;

  const AdminDevicesPage({super.key, this.initialFilter});

  static AdminDevicesPage withQueryFilter(String? raw) {
    switch (raw) {
      case 'online':
        return const AdminDevicesPage(initialFilter: _DeviceFilter.online);
      case 'offline':
        return const AdminDevicesPage(initialFilter: _DeviceFilter.offline);
      case 'blocked':
        return const AdminDevicesPage(initialFilter: _DeviceFilter.blocked);
      case 'expiring':
      case 'expiringSoon':
        return const AdminDevicesPage(
            initialFilter: _DeviceFilter.expiringSoon);
      case 'outdated':
        return const AdminDevicesPage(initialFilter: _DeviceFilter.outdated);
      default:
        return const AdminDevicesPage();
    }
  }

  @override
  ConsumerState<AdminDevicesPage> createState() => _AdminDevicesPageState();
}

class _AdminDevicesPageState extends ConsumerState<AdminDevicesPage> {
  final _searchController = TextEditingController();
  String _query = '';
  late _DeviceFilter _filter = widget.initialFilter ?? _DeviceFilter.all;
  _DeviceSort _sort = _DeviceSort.lastSeen;

  final Set<String> _selectedIds = <String>{};
  bool _selecting = false;

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
        _FilterRow(
          value: _filter,
          onChanged: (f) => setState(() => _filter = f),
          sort: _sort,
          onSortChanged: (s) => setState(() => _sort = s),
          selecting: _selecting,
          selectedCount: _selectedIds.length,
          onToggleSelecting: () {
            setState(() {
              _selecting = !_selecting;
              if (!_selecting) _selectedIds.clear();
            });
          },
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
                return const AdminSkeletonList();
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final all = snap.data?.docs ?? const [];
              final maxVersion =
                  AdminHeuristics.maxAppVersion(all.map((d) => d.data()));
              final docs = all
                  .where((d) => _matches(d.data(), maxVersion: maxVersion))
                  .toList();
              docs.sort(_compareByCurrentSort);

              if (docs.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: [
                      AdminEmptyState(
                        icon: Icons.devices_other_outlined,
                        title: 'No devices match',
                        subtitle: _query.isNotEmpty ||
                                _filter != _DeviceFilter.all
                            ? 'Try clearing your filters.'
                            : 'Devices appear as they heartbeat in.',
                        actionLabel: (_query.isNotEmpty ||
                                _filter != _DeviceFilter.all)
                            ? 'Clear filters'
                            : null,
                        onAction: (_query.isNotEmpty ||
                                _filter != _DeviceFilter.all)
                            ? () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _filter = _DeviceFilter.all;
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
                  itemBuilder: (context, i) => _DeviceTile(
                    installId: docs[i].id,
                    data: docs[i].data(),
                    maxVersion: maxVersion,
                    selecting: _selecting,
                    selected: _selectedIds.contains(docs[i].id),
                    onTap: () {
                      if (_selecting) {
                        setState(() {
                          if (_selectedIds.contains(docs[i].id)) {
                            _selectedIds.remove(docs[i].id);
                          } else {
                            _selectedIds.add(docs[i].id);
                          }
                        });
                      } else {
                        context.push('/admin/devices/${docs[i].id}');
                      }
                    },
                    onLongPress: () {
                      setState(() {
                        _selecting = true;
                        _selectedIds.add(docs[i].id);
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
        if (_selecting && _selectedIds.isNotEmpty)
          _BulkActionsBar(
            selectedIds: _selectedIds.toList(),
            onDone: () => setState(() {
              _selecting = false;
              _selectedIds.clear();
            }),
          ),
      ],
    );
  }

  Future<void> _refresh() async {
    if (mounted) setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  bool _matches(
    Map<String, dynamic> data, {
    required String? maxVersion,
  }) {
    if (_query.isNotEmpty) {
      final hay = [
        data['deviceName'],
        data['shopName'],
        data['platform'],
        data['model'],
        data['appVersion'],
      ].whereType<String>().join(' ').toLowerCase();
      if (!hay.contains(_query)) return false;
    }
    final status = AdminHeuristics.deviceStatus(data);
    final version = data['appVersion'] as String?;
    final isOutdated = maxVersion != null &&
        version != null &&
        version.isNotEmpty &&
        AdminHeuristics.compareAppVersions(version, maxVersion) < 0;

    switch (_filter) {
      case _DeviceFilter.all:
        return true;
      case _DeviceFilter.online:
        return status == DeviceStatus.online;
      case _DeviceFilter.offline:
        return status == DeviceStatus.offline;
      case _DeviceFilter.blocked:
        return status == DeviceStatus.blocked;
      case _DeviceFilter.expiringSoon:
        return status == DeviceStatus.expiringSoon ||
            status == DeviceStatus.expired;
      case _DeviceFilter.outdated:
        return isOutdated;
    }
  }

  int _compareByCurrentSort(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    switch (_sort) {
      case _DeviceSort.lastSeen:
        final ai = (a.data()['lastSeenAtIso'] as String?) ?? '';
        final bi = (b.data()['lastSeenAtIso'] as String?) ?? '';
        return bi.compareTo(ai);
      case _DeviceSort.deviceName:
        final an = (a.data()['deviceName'] as String?)?.toLowerCase() ?? '';
        final bn = (b.data()['deviceName'] as String?)?.toLowerCase() ?? '';
        return an.compareTo(bn);
      case _DeviceSort.appVersion:
        return AdminHeuristics.compareAppVersions(
          b.data()['appVersion'] as String?,
          a.data()['appVersion'] as String?,
        );
    }
  }
}

class _FilterRow extends StatelessWidget {
  final _DeviceFilter value;
  final ValueChanged<_DeviceFilter> onChanged;
  final _DeviceSort sort;
  final ValueChanged<_DeviceSort> onSortChanged;
  final bool selecting;
  final int selectedCount;
  final VoidCallback onToggleSelecting;

  const _FilterRow({
    required this.value,
    required this.onChanged,
    required this.sort,
    required this.onSortChanged,
    required this.selecting,
    required this.selectedCount,
    required this.onToggleSelecting,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All', _DeviceFilter.all),
          _chip('Online', _DeviceFilter.online),
          _chip('Offline 3d+', _DeviceFilter.offline),
          _chip('Blocked', _DeviceFilter.blocked),
          _chip('Expiring', _DeviceFilter.expiringSoon),
          _chip('Outdated', _DeviceFilter.outdated),
          const SizedBox(width: AppTokens.space2),
          PopupMenuButton<_DeviceSort>(
            tooltip: 'Sort',
            initialValue: sort,
            onSelected: onSortChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: _DeviceSort.lastSeen, child: Text('Sort: Last seen')),
              PopupMenuItem(
                  value: _DeviceSort.deviceName, child: Text('Sort: Name')),
              PopupMenuItem(
                  value: _DeviceSort.appVersion,
                  child: Text('Sort: App version')),
            ],
            child: Chip(
              avatar: const Icon(Icons.sort, size: 16),
              label: Text(_sortLabel(sort)),
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          ActionChip(
            avatar: Icon(
              selecting ? Icons.cancel : Icons.check_box_outlined,
              size: 16,
            ),
            label: Text(
              selecting
                  ? (selectedCount == 0
                      ? 'Cancel'
                      : 'Selected $selectedCount')
                  : 'Select',
            ),
            onPressed: onToggleSelecting,
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _DeviceFilter f) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: value == f,
        onSelected: (_) => onChanged(f),
      ),
    );
  }

  static String _sortLabel(_DeviceSort s) {
    switch (s) {
      case _DeviceSort.lastSeen:
        return 'Last seen';
      case _DeviceSort.deviceName:
        return 'Name';
      case _DeviceSort.appVersion:
        return 'App version';
    }
  }
}

class _DeviceTile extends StatelessWidget {
  final String installId;
  final Map<String, dynamic> data;
  final String? maxVersion;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DeviceTile({
    required this.installId,
    required this.data,
    required this.maxVersion,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final name = (data['deviceName'] as String?)?.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : installId.substring(0, 8);
    final shopName = data['shopName'] as String?;
    final platform = data['platform'] as String?;
    final lastSeenIso = data['lastSeenAtIso'] as String?;
    final lastSeen = lastSeenIso != null ? DateTime.tryParse(lastSeenIso) : null;
    final version = data['appVersion'] as String?;
    final isOutdated = maxVersion != null &&
        version != null &&
        version.isNotEmpty &&
        AdminHeuristics.compareAppVersions(version, maxVersion!) < 0;

    return GestureDetector(
      onLongPress: onLongPress,
      child: AppPanel(
        onTap: onTap,
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.06)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space2,
            vertical: AppTokens.space2,
          ),
          child: Row(
            children: [
              if (selecting)
                Padding(
                  padding: const EdgeInsets.only(right: AppTokens.space2),
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : extras.muted,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppTokens.space1),
                        AdminStatusBadge(
                          data: data,
                          isDevice: true,
                          outdated: isOutdated,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (shopName != null && shopName.isNotEmpty) shopName,
                        if (platform != null && platform.isNotEmpty) platform,
                        if (version != null && version.isNotEmpty) 'v$version',
                        if (lastSeen != null)
                          'seen ${AdminHeuristics.relativeShort(lastSeen)}',
                      ].join('  \u00B7  '),
                      style: TextStyle(color: extras.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space1),
              if (!selecting) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom bar visible during multi-select. Commits bulk Block, Unblock,
/// extend expiry, and clear expiry operations as a single WriteBatch.
class _BulkActionsBar extends ConsumerStatefulWidget {
  final List<String> selectedIds;
  final VoidCallback onDone;

  const _BulkActionsBar({
    required this.selectedIds,
    required this.onDone,
  });

  @override
  ConsumerState<_BulkActionsBar> createState() => _BulkActionsBarState();
}

class _BulkActionsBarState extends ConsumerState<_BulkActionsBar> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space2,
        AppTokens.space2,
        AppTokens.space2,
        AppTokens.space2,
      ),
      decoration: BoxDecoration(
        color: extras.panel,
        border: Border(
          top: BorderSide(color: extras.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${widget.selectedIds.length} device(s) selected',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_working)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                onSelected: (v) => _dispatch(v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'block', child: Text('Block')),
                  PopupMenuItem(value: 'unblock', child: Text('Unblock')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: '30', child: Text('Extend +30 days')),
                  PopupMenuItem(value: '90', child: Text('Extend +90 days')),
                  PopupMenuItem(value: '365', child: Text('Extend +1 year')),
                  PopupMenuItem(value: 'clear', child: Text('Clear expiry')),
                ],
              ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: _working ? null : widget.onDone,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dispatch(String action) async {
    final confirm = await _confirm(action);
    if (!confirm) return;
    final db = ref.read(adminAuthServiceProvider).db;
    if (db == null) return;
    setState(() => _working = true);
    try {
      final batch = db.batch();
      final auditColl = <String, CollectionReference<Map<String, dynamic>>>{};
      final auditPayload = <String, Map<String, dynamic>>{};
      final now = DateTime.now();
      final extendDays = int.tryParse(action);

      for (final id in widget.selectedIds) {
        final ref = db
            .collection(FirestorePaths.devicesCollection)
            .doc(id);

        Map<String, dynamic> payload;
        String actionLabel;
        if (action == 'block') {
          payload = {'blocked': true};
          actionLabel = 'Bulk blocked device';
        } else if (action == 'unblock') {
          payload = {'blocked': false};
          actionLabel = 'Bulk unblocked device';
        } else if (action == 'clear') {
          payload = {'expiresAt': null};
          actionLabel = 'Bulk cleared device expiry';
        } else if (extendDays != null) {
          final end = DateTime(
            now.year,
            now.month,
            now.day + extendDays,
            23,
            59,
            59,
          );
          payload = {'expiresAt': end.toIso8601String()};
          actionLabel =
              'Bulk extended device expiry by $extendDays days';
        } else {
          continue;
        }

        batch.set(ref, payload, SetOptions(merge: true));
        auditColl[id] = ref.collection('auditLog');
        auditPayload[id] = payload;
        // Audit entry committed in the same batch.
        final auditDoc = ref.collection('auditLog').doc();
        batch.set(auditDoc, {
          'at': FieldValue.serverTimestamp(),
          'atIso': DateTime.now().toIso8601String(),
          'actorUid': ref.firestore.app.options.projectId,
          // The admin's uid / email is filled by the audit service for
          // non-batched writes. For the batch we read it from the
          // AdminAuthService directly.
          ..._actorFields(),
          'action': actionLabel,
          'targetType': 'device',
          'targetId': id,
          'changes': _diffForPayload(payload),
        });
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.selectedIds.length} device(s) updated.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Map<String, dynamic> _actorFields() {
    final auth = ref.read(adminAuthServiceProvider);
    return {
      'actorUid': auth.currentUid,
      'actorEmail': auth.currentEmail,
    };
  }

  /// Minimal diff map so the audit entry has consistent shape. Because
  /// we only know "after" in a bulk context, "old" is recorded as null.
  Map<String, Map<String, dynamic>> _diffForPayload(
      Map<String, dynamic> payload) {
    final out = <String, Map<String, dynamic>>{};
    payload.forEach((k, v) {
      out[k] = {'old': null, 'new': v is DateTime ? v.toIso8601String() : v};
    });
    return out;
  }

  Future<bool> _confirm(String action) async {
    String? title;
    String message = '';
    if (action == 'block') {
      title = 'Block ${widget.selectedIds.length} device(s)?';
      message = 'They will lock immediately and stay locked until unblocked.';
    } else if (action == 'clear') {
      title = 'Clear expiry on ${widget.selectedIds.length} device(s)?';
      message = 'They will fall back to the shop expiry.';
    }
    if (title == null) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title!),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

// Suppress unused imports that were imported because of helpers the
// bulk bar may need in the future.
// ignore: unused_element
void _ensureAuditServiceLinked() {
  AdminAuditService();
}
