import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/account_state.dart';
import '../../../providers/account_provider.dart';
import '../../../services/cloud/firestore_paths.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_badge.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_section_header.dart';

/// Owner-facing screen that lists members of the current business and
/// lets the owner approve, reject, or remove staff. The page reads
/// /shops/{shopId}/members directly via the device's anonymous-auth
/// Firestore instance — the security rules restrict the staff approval
/// writes to the approved owner.
class TeamManagementPage extends ConsumerWidget {
  const TeamManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentAccountStateProvider);
    final extras = context.appExtras;

    if (account.firebaseUnavailable) {
      return _wrap(
        body: AppPanel(
          padding: const EdgeInsets.all(AppTokens.space3),
          child: Text(
            'Cloud is not configured on this device. Team management '
            'requires Firebase to be set up.',
            style: TextStyle(color: extras.muted),
          ),
        ),
      );
    }
    if (account.shopId == null || account.shopId!.isEmpty) {
      return _wrap(
        body: const AppPanel(
          padding: EdgeInsets.all(AppTokens.space3),
          child: Text(
            'No business is linked to this device yet. Complete '
            'onboarding first.',
          ),
        ),
      );
    }
    if (account.role != AccountRole.owner) {
      return _wrap(
        body: const AppPanel(
          padding: EdgeInsets.all(AppTokens.space3),
          child: Text(
            'Only the business owner can approve staff requests. Ask '
            'your owner to manage the team.',
          ),
        ),
      );
    }
    if (account.stage != AccountStage.approved) {
      return _wrap(
        body: const AppPanel(
          padding: EdgeInsets.all(AppTokens.space3),
          child: Text(
            'Your business is not approved yet. You will be able to '
            'manage staff once the system administrator approves you.',
          ),
        ),
      );
    }

    final shopId = account.shopId!;
    final stream = FirebaseFirestore.instance
        .collection(FirestorePaths.shopsCollection)
        .doc(shopId)
        .collection(FirestorePaths.membersSubcollection)
        .snapshots();

    return _wrap(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? const [];
          final pending = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final approved = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final rejected = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          for (final d in docs) {
            final status = (d.data()[AccountApproval.fieldStatus]
                    as String?) ??
                AccountApproval.statusApproved;
            switch (status) {
              case AccountApproval.statusPendingOwner:
                pending.add(d);
                break;
              case AccountApproval.statusRejected:
                rejected.add(d);
                break;
              default:
                approved.add(d);
            }
          }
          approved.sort(_compareByName);
          pending.sort(_compareByName);
          rejected.sort(_compareByName);

          return ListView(
            padding: const EdgeInsets.all(AppTokens.space3),
            children: [
              _SummaryCard(
                pending: pending.length,
                approved: approved.length,
                rejected: rejected.length,
                businessName: account.shopName,
              ),
              const SizedBox(height: AppTokens.space3),
              if (pending.isEmpty)
                const AppSectionHeader(title: 'Pending requests')
              else
                AppSectionHeader(
                  title: 'Pending requests (${pending.length})',
                ),
              if (pending.isEmpty)
                AppPanel(
                  padding: const EdgeInsets.all(AppTokens.space3),
                  child: Text(
                    'No pending staff requests right now.',
                    style: TextStyle(color: extras.muted),
                  ),
                )
              else
                ...pending.map((d) => _MemberTile(
                      shopId: shopId,
                      docId: d.id,
                      data: d.data(),
                      isOwnerSelf: false,
                    )),
              const SizedBox(height: AppTokens.space3),
              const AppSectionHeader(title: 'Approved members'),
              if (approved.isEmpty)
                AppPanel(
                  padding: const EdgeInsets.all(AppTokens.space3),
                  child: Text(
                    'No approved members yet.',
                    style: TextStyle(color: extras.muted),
                  ),
                )
              else
                ...approved.map((d) => _MemberTile(
                      shopId: shopId,
                      docId: d.id,
                      data: d.data(),
                      isOwnerSelf:
                          d.data()['role'] == AccountApproval.roleOwner,
                    )),
              if (rejected.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space3),
                AppSectionHeader(
                  title: 'Rejected (${rejected.length})',
                ),
                ...rejected.map((d) => _MemberTile(
                      shopId: shopId,
                      docId: d.id,
                      data: d.data(),
                      isOwnerSelf: false,
                    )),
              ],
              const SizedBox(height: AppTokens.space4),
            ],
          );
        },
      ),
    );
  }

  static int _compareByName(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final an = ((a.data()['displayName'] as String?) ?? '').toLowerCase();
    final bn = ((b.data()['displayName'] as String?) ?? '').toLowerCase();
    return an.compareTo(bn);
  }

  Widget _wrap({required Widget body}) {
    return AppPageScaffold(
      appBar: AppBar(
        title: const Text(
          'Team',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      padding: const EdgeInsets.all(AppTokens.space3),
      child: body,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int pending;
  final int approved;
  final int rejected;
  final String? businessName;

  const _SummaryCard({
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.businessName,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final theme = Theme.of(context);

    return AppPanel(
      emphasized: true,
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Team for ${businessName ?? 'your business'}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppTokens.space2),
          Row(
            children: [
              _stat(context, 'Pending', pending, extras.warning),
              const SizedBox(width: AppTokens.space3),
              _stat(context, 'Approved', approved, extras.success),
              const SizedBox(width: AppTokens.space3),
              _stat(context, 'Rejected', rejected, extras.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int value, Color color) {
    final extras = context.appExtras;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: extras.muted, fontSize: 11)),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontFamily: 'IBMPlexMono',
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends ConsumerStatefulWidget {
  final String shopId;
  final String docId;
  final Map<String, dynamic> data;
  final bool isOwnerSelf;

  const _MemberTile({
    required this.shopId,
    required this.docId,
    required this.data,
    required this.isOwnerSelf,
  });

  @override
  ConsumerState<_MemberTile> createState() => _MemberTileState();
}

class _MemberTileState extends ConsumerState<_MemberTile> {
  bool _busy = false;

  String? _readString(String key) {
    final v = widget.data[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(accountServiceProvider)
          .ownerApproveMember(
            shopId: widget.shopId,
            memberUid: widget.docId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add an optional reason. The staff member will see this '
              'message.',
            ),
            const SizedBox(height: AppTokens.space2),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(accountServiceProvider)
          .ownerRejectMember(
            shopId: widget.shopId,
            memberUid: widget.docId,
            reason: controller.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this member?'),
        content: const Text(
          'They will no longer have access to this business on their '
          'device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(accountServiceProvider)
          .ownerRemoveMember(
            shopId: widget.shopId,
            memberUid: widget.docId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final theme = Theme.of(context);
    final data = widget.data;
    final status = (data[AccountApproval.fieldStatus] as String?) ??
        AccountApproval.statusApproved;
    final role = (data['role'] as String?) ?? AccountApproval.roleStaff;
    final displayName =
        _readString('displayName') ?? widget.docId.substring(0, 8);
    final phone = _readString('phone');
    final isPending = status == AccountApproval.statusPendingOwner;
    final isRejected = status == AccountApproval.statusRejected;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppTokens.space1),
      padding: const EdgeInsets.all(AppTokens.space2),
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
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        role == AccountApproval.roleOwner ? 'Owner' : 'Staff',
                        if (phone != null) phone,
                      ].join('  \u00B7  '),
                      style: TextStyle(color: extras.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
          if (isRejected &&
              _readString(AccountApproval.fieldRejectionReason) != null) ...[
            const SizedBox(height: AppTokens.space1),
            Text(
              'Reason: ${_readString(AccountApproval.fieldRejectionReason)}',
              style: theme.textTheme.bodySmall?.copyWith(color: extras.muted),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: AppTokens.space2),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _approve,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: AppTokens.space2),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _reject,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ] else if (!widget.isOwnerSelf) ...[
            const SizedBox(height: AppTokens.space2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy ? null : _remove,
                icon: Icon(Icons.delete_outline, size: 16, color: extras.danger),
                label: Text(
                  'Remove',
                  style: TextStyle(color: extras.danger),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case AccountApproval.statusPendingOwner:
        return const AppBadge(label: 'Pending', tone: AppBadgeTone.warning);
      case AccountApproval.statusRejected:
        return const AppBadge(label: 'Rejected', tone: AppBadgeTone.danger);
      default:
        return const AppBadge(label: 'Approved', tone: AppBadgeTone.success);
    }
  }
}
