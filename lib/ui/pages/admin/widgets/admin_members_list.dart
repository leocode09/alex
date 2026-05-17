import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../services/cloud/firestore_paths.dart';
import '../../../design_system/app_theme_extensions.dart';
import '../../../design_system/app_tokens.dart';
import '../../../design_system/widgets/app_badge.dart';
import '../../../design_system/widgets/app_panel.dart';
import '../admin_heuristics.dart';

/// Admin-side list of the members under a shop. Lets the system admin
/// see the team and approve/reject staff requests directly (mirroring
/// the owner-side workflow with full override). Writes go through the
/// admin Firestore instance so the admin allowlist controls access.
class AdminMembersList extends StatelessWidget {
  final FirebaseFirestore db;
  final String shopId;

  const AdminMembersList({
    super.key,
    required this.db,
    required this.shopId,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection(FirestorePaths.shopsCollection)
          .doc(shopId)
          .collection(FirestorePaths.membersSubcollection)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppTokens.space2),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return AppPanel(child: Text('Error: ${snap.error}'));
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return AppPanel(
            padding: const EdgeInsets.all(AppTokens.space3),
            child: Text(
              'No members yet.',
              style: TextStyle(color: extras.muted),
            ),
          );
        }
        final sorted = [...docs]
          ..sort((a, b) {
            // Pending first, then approved, then rejected.
            final ar = _orderForStatus(a.data()['approvalStatus'] as String?);
            final br = _orderForStatus(b.data()['approvalStatus'] as String?);
            if (ar != br) return ar.compareTo(br);
            final an = (a.data()['displayName'] as String?)?.toLowerCase() ?? '';
            final bn = (b.data()['displayName'] as String?)?.toLowerCase() ?? '';
            return an.compareTo(bn);
          });
        return Column(
          children: [
            for (final d in sorted)
              _MemberTile(
                db: db,
                shopId: shopId,
                docId: d.id,
                data: d.data(),
              ),
          ],
        );
      },
    );
  }

  static int _orderForStatus(String? s) {
    switch (s) {
      case 'pendingOwner':
        return 0;
      case 'pendingSystemAdmin':
        return 1;
      case 'approved':
        return 2;
      case 'rejected':
        return 3;
      default:
        return 2;
    }
  }
}

class _MemberTile extends StatefulWidget {
  final FirebaseFirestore db;
  final String shopId;
  final String docId;
  final Map<String, dynamic> data;

  const _MemberTile({
    required this.db,
    required this.shopId,
    required this.docId,
    required this.data,
  });

  @override
  State<_MemberTile> createState() => _MemberTileState();
}

class _MemberTileState extends State<_MemberTile> {
  bool _busy = false;

  Future<void> _setStatus(String status, {String? reason}) async {
    setState(() => _busy = true);
    try {
      final payload = <String, dynamic>{
        'approvalStatus': status,
      };
      final nowIso = DateTime.now().toIso8601String();
      if (status == 'approved') {
        payload['approvedAt'] = nowIso;
        payload['rejectedAt'] = null;
        payload['rejectionReason'] = null;
      } else if (status == 'rejected') {
        payload['rejectedAt'] = nowIso;
        if (reason != null && reason.trim().isNotEmpty) {
          payload['rejectionReason'] = reason.trim();
        }
      }
      await widget.db
          .collection(FirestorePaths.shopsCollection)
          .doc(widget.shopId)
          .collection(FirestorePaths.membersSubcollection)
          .doc(widget.docId)
          .set(payload, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $status.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
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
          'This member loses access on their device immediately.',
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
      await widget.db
          .collection(FirestorePaths.shopsCollection)
          .doc(widget.shopId)
          .collection(FirestorePaths.membersSubcollection)
          .doc(widget.docId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member removed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promptReject() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this member?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add an optional reason. The member will see this on '
              'their device.',
            ),
            const SizedBox(height: AppTokens.space2),
            TextField(
              controller: controller,
              decoration:
                  const InputDecoration(labelText: 'Reason (optional)'),
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
    if (confirmed != true) return;
    await _setStatus('rejected', reason: controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final data = widget.data;
    final approval = AdminHeuristics.approvalStatus(data);
    final role = (data['role'] as String?) ?? 'staff';
    final displayName =
        ((data['displayName'] as String?) ?? widget.docId).trim();
    final phone = (data['phone'] as String?)?.trim();
    final isOwner = role == 'owner';

    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppTokens.space1),
      padding: const EdgeInsets.all(AppTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isEmpty ? widget.docId : displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      [
                        isOwner ? 'Owner' : 'Staff',
                        if (phone != null && phone.isNotEmpty) phone,
                      ].join('  \u00B7  '),
                      style: TextStyle(color: extras.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _badge(approval),
            ],
          ),
          if (approval == ApprovalStatus.rejected &&
              (data['rejectionReason'] as String?)?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Reason: ${(data['rejectionReason'] as String).trim()}',
                style: TextStyle(color: extras.muted, fontSize: 12),
              ),
            ),
          const SizedBox(height: AppTokens.space2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (approval != ApprovalStatus.approved)
                FilledButton.icon(
                  onPressed: _busy ? null : () => _setStatus('approved'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                ),
              if (approval != ApprovalStatus.rejected && !isOwner)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _promptReject,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                ),
              if (!isOwner)
                TextButton.icon(
                  onPressed: _busy ? null : _remove,
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: extras.danger),
                  label: Text(
                    'Remove',
                    style: TextStyle(color: extras.danger),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(ApprovalStatus s) {
    switch (s) {
      case ApprovalStatus.pendingOwner:
        return const AppBadge(
          label: 'Pending owner',
          tone: AppBadgeTone.warning,
        );
      case ApprovalStatus.pendingSystemAdmin:
        return const AppBadge(
          label: 'Pending review',
          tone: AppBadgeTone.warning,
        );
      case ApprovalStatus.rejected:
        return const AppBadge(
          label: 'Rejected',
          tone: AppBadgeTone.danger,
        );
      case ApprovalStatus.approved:
        return const AppBadge(
          label: 'Approved',
          tone: AppBadgeTone.success,
        );
    }
  }
}
