import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/admin_auth_provider.dart';
import '../../../../services/admin/admin_audit_service.dart';
import '../../../../services/cloud/firestore_paths.dart';
import '../../../design_system/app_theme_extensions.dart';
import '../../../design_system/app_tokens.dart';
import '../../../design_system/widgets/app_panel.dart';
import '../admin_heuristics.dart';

/// Target of the quick actions row.
enum AdminQuickTarget { shop, device }

/// Standard "admin-ops" row. Applies to either a shop or a device and
/// shows the most common one-tap operations:
///
///   - +30d / +90d / +1y  (adds to existing expiry or sets from today)
///   - Clear expiry
///   - Disable / Enable shop        (shops only)
///   - Block / Unblock              (devices only)
///
/// Destructive actions (disable shop, block device, clear a future
/// expiry) trigger a confirmation dialog. Every successful write is
/// audited via [AdminAuditService] and surfaces a SnackBar toast.
class AdminQuickActions extends ConsumerWidget {
  final AdminQuickTarget target;
  final String targetId;
  final Map<String, dynamic> data;

  const AdminQuickActions({
    super.key,
    required this.target,
    required this.targetId,
    required this.data,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = context.appExtras;
    final isShop = target == AdminQuickTarget.shop;

    final expiryKey = isShop ? 'licenseExpiresAt' : 'expiresAt';
    final expiresAt = AdminHeuristics.parseTs(data[expiryKey]);
    final hasExpiry = expiresAt != null;

    final isShopEnabled = isShop ? (data['enabled'] as bool? ?? true) : true;
    final isBlocked = !isShop && (data['blocked'] as bool? ?? false);

    return AppPanel(
      padding: const EdgeInsets.all(AppTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: extras.muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
          ),
          const SizedBox(height: AppTokens.space2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionChip(
                context,
                icon: Icons.add,
                label: '+30 days',
                onTap: () => _extendExpiry(context, ref, days: 30),
              ),
              _actionChip(
                context,
                icon: Icons.add,
                label: '+90 days',
                onTap: () => _extendExpiry(context, ref, days: 90),
              ),
              _actionChip(
                context,
                icon: Icons.add,
                label: '+1 year',
                onTap: () => _extendExpiry(context, ref, days: 365),
              ),
              if (hasExpiry)
                _actionChip(
                  context,
                  icon: Icons.clear,
                  label: 'Clear expiry',
                  destructive: expiresAt.isAfter(DateTime.now()),
                  onTap: () => _clearExpiry(context, ref),
                ),
              if (isShop)
                _actionChip(
                  context,
                  icon: isShopEnabled
                      ? Icons.power_settings_new
                      : Icons.play_arrow,
                  label: isShopEnabled ? 'Disable shop' : 'Enable shop',
                  destructive: isShopEnabled,
                  onTap: () => _toggleShopEnabled(
                    context,
                    ref,
                    nextEnabled: !isShopEnabled,
                  ),
                ),
              if (!isShop)
                _actionChip(
                  context,
                  icon: isBlocked ? Icons.check : Icons.block,
                  label: isBlocked ? 'Unblock' : 'Block',
                  destructive: !isBlocked,
                  onTap: () => _toggleDeviceBlocked(
                    context,
                    ref,
                    nextBlocked: !isBlocked,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool destructive = false,
    required VoidCallback onTap,
  }) {
    final extras = context.appExtras;
    final fg = destructive ? extras.danger : Theme.of(context).colorScheme.primary;
    return ActionChip(
      avatar: Icon(icon, size: 16, color: fg),
      label: Text(label),
      labelStyle: TextStyle(
        color: fg,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: extras.border),
      backgroundColor: Colors.transparent,
      onPressed: onTap,
    );
  }

  // ---------- actions ----------

  DocumentReference<Map<String, dynamic>>? _ref(WidgetRef ref) {
    final db = ref.read(adminAuthServiceProvider).db;
    if (db == null) return null;
    if (target == AdminQuickTarget.shop) {
      return db
          .collection(FirestorePaths.shopsCollection)
          .doc(targetId);
    }
    return db
        .collection(FirestorePaths.devicesCollection)
        .doc(targetId);
  }

  Future<void> _extendExpiry(
    BuildContext context,
    WidgetRef ref, {
    required int days,
  }) async {
    final key = target == AdminQuickTarget.shop
        ? 'licenseExpiresAt'
        : 'expiresAt';
    final current = AdminHeuristics.parseTs(data[key]);
    final base = current != null && current.isAfter(DateTime.now())
        ? current
        : DateTime.now();
    final next = DateTime(
      base.year,
      base.month,
      base.day + days,
      23,
      59,
      59,
    );
    await _commit(
      context,
      ref,
      before: data,
      payload: {key: next.toIso8601String()},
      action:
          'Extended expiry by $days days (to ${AdminHeuristics.fmtDate(next)})',
      successMessage: 'Expiry set to ${AdminHeuristics.fmtDate(next)}',
    );
  }

  Future<void> _clearExpiry(BuildContext context, WidgetRef ref) async {
    final key = target == AdminQuickTarget.shop
        ? 'licenseExpiresAt'
        : 'expiresAt';
    final current = AdminHeuristics.parseTs(data[key]);
    if (current != null && current.isAfter(DateTime.now())) {
      final confirm = await _confirm(
        context,
        title: 'Clear active expiry?',
        message:
            'The current expiry is ${AdminHeuristics.fmtDate(current)} '
            '(in the future). Clearing it grants unlimited access.',
        confirmLabel: 'Clear expiry',
      );
      if (!confirm) return;
    }
    if (!context.mounted) return;
    await _commit(
      context,
      ref,
      before: data,
      payload: {key: null},
      action: 'Cleared expiry',
      successMessage: 'Expiry cleared',
    );
  }

  Future<void> _toggleShopEnabled(
    BuildContext context,
    WidgetRef ref, {
    required bool nextEnabled,
  }) async {
    if (!nextEnabled) {
      final confirm = await _confirm(
        context,
        title: 'Disable this shop?',
        message:
            'Every device attached to this shop will immediately be '
            'locked to the license screen. They will unlock again when '
            'you re-enable the shop.',
        confirmLabel: 'Disable',
      );
      if (!confirm) return;
    }
    if (!context.mounted) return;
    await _commit(
      context,
      ref,
      before: data,
      payload: {'enabled': nextEnabled},
      action: nextEnabled ? 'Enabled shop' : 'Disabled shop',
      successMessage: nextEnabled ? 'Shop enabled' : 'Shop disabled',
    );
  }

  Future<void> _toggleDeviceBlocked(
    BuildContext context,
    WidgetRef ref, {
    required bool nextBlocked,
  }) async {
    if (nextBlocked) {
      final confirm = await _confirm(
        context,
        title: 'Block this device?',
        message:
            'The app on this device will be locked immediately and '
            'stay locked until you unblock it.',
        confirmLabel: 'Block device',
      );
      if (!confirm) return;
    }
    if (!context.mounted) return;
    await _commit(
      context,
      ref,
      before: data,
      payload: {'blocked': nextBlocked},
      action: nextBlocked ? 'Blocked device' : 'Unblocked device',
      successMessage: nextBlocked ? 'Device blocked' : 'Device unblocked',
    );
  }

  // ---------- core commit + audit ----------

  Future<void> _commit(
    BuildContext context,
    WidgetRef ref, {
    required Map<String, dynamic> before,
    required Map<String, dynamic> payload,
    required String action,
    required String successMessage,
  }) async {
    final docRef = _ref(ref);
    if (docRef == null) {
      _toast(context, 'Admin is not signed in.');
      return;
    }
    try {
      await docRef.set(payload, SetOptions(merge: true));
      final after = <String, dynamic>{...before, ...payload};
      if (target == AdminQuickTarget.shop) {
        await AdminAuditService().recordShopChange(
          shopId: targetId,
          before: before,
          after: after,
          action: action,
        );
      } else {
        await AdminAuditService().recordDeviceChange(
          installId: targetId,
          before: before,
          after: after,
          action: action,
        );
      }
      if (context.mounted) {
        _toast(context, successMessage);
      }
    } catch (e) {
      if (context.mounted) {
        _toast(context, 'Failed: $e');
      }
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
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
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
