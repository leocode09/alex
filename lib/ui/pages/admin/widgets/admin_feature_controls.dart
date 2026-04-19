import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/license_policy.dart';
import '../../../../providers/admin_auth_provider.dart';
import '../../../../services/admin/admin_audit_service.dart';
import '../../../../services/cloud/firestore_paths.dart';
import '../../../design_system/app_theme_extensions.dart';
import '../../../design_system/app_tokens.dart';
import '../../../design_system/widgets/app_panel.dart';

/// Distinguishes shop-scoped and device-scoped editing. The UI differs
/// slightly: shops expose every knob (expiry, flags, PIN-force, notice,
/// quotas, kill-switch); per-device editors expose only the overrides
/// (per-device expiry, per-feature overrides, block).
sealed class AdminFeatureTarget {
  const AdminFeatureTarget();
  const factory AdminFeatureTarget.shop({required String shopId}) =
      _ShopTarget;
  const factory AdminFeatureTarget.device({required String installId}) =
      _DeviceTarget;
}

class _ShopTarget extends AdminFeatureTarget {
  final String shopId;
  const _ShopTarget({required this.shopId});
}

class _DeviceTarget extends AdminFeatureTarget {
  final String installId;
  const _DeviceTarget({required this.installId});
}

/// Shared editor widget used on both the shop-detail and device-detail
/// pages. Writes are fire-and-forget: each toggle calls `set(..., merge)`
/// on the target Firestore doc and surfaces errors in a SnackBar.
class AdminFeatureControls extends ConsumerStatefulWidget {
  final AdminFeatureTarget target;
  final Map<String, dynamic> data;

  const AdminFeatureControls({
    super.key,
    required this.target,
    required this.data,
  });

  @override
  ConsumerState<AdminFeatureControls> createState() =>
      _AdminFeatureControlsState();
}

class _AdminFeatureControlsState
    extends ConsumerState<AdminFeatureControls> {
  final _noticeController = TextEditingController();
  final _maxProductsController = TextEditingController();
  final _maxSalesController = TextEditingController();
  bool _initializedControllers = false;

  @override
  void didUpdateWidget(covariant AdminFeatureControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  void _syncControllers() {
    final data = widget.data;
    if (!_initializedControllers) {
      _noticeController.text = (data['notice'] as String?) ?? '';
      _maxProductsController.text =
          (data['maxProducts'] as num?)?.toInt().toString() ?? '';
      _maxSalesController.text =
          (data['maxSalesPerDay'] as num?)?.toInt().toString() ?? '';
      _initializedControllers = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void dispose() {
    _noticeController.dispose();
    _maxProductsController.dispose();
    _maxSalesController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> _ref() {
    final db = ref.read(adminAuthServiceProvider).db!;
    final target = widget.target;
    if (target is _ShopTarget) {
      return db
          .collection(FirestorePaths.shopsCollection)
          .doc(target.shopId);
    }
    final dt = target as _DeviceTarget;
    return db
        .collection(FirestorePaths.devicesCollection)
        .doc(dt.installId);
  }

  /// Updates the target doc with [payload] (merged) and records an
  /// audit entry describing the change.
  ///
  /// [action] is the human-readable label stored in the audit log
  /// ("Enabled shop", "Set expiry to 2026-12-31", etc.). When
  /// [successMessage] is provided, it is shown as a SnackBar on
  /// success. When [confirm] is provided, a confirmation dialog must
  /// be acknowledged before the write happens.
  Future<void> _update(
    Map<String, dynamic> payload, {
    required String action,
    String? successMessage,
    _ConfirmSpec? confirm,
  }) async {
    if (confirm != null) {
      final ok = await _askConfirm(confirm);
      if (!ok) return;
    }
    final before = Map<String, dynamic>.from(widget.data);
    try {
      await _ref().set(payload, SetOptions(merge: true));
      final after = _mergeForDiff(before, payload);
      final target = widget.target;
      if (target is _ShopTarget) {
        await AdminAuditService().recordShopChange(
          shopId: target.shopId,
          before: before,
          after: after,
          action: action,
        );
      } else if (target is _DeviceTarget) {
        await AdminAuditService().recordDeviceChange(
          installId: target.installId,
          before: before,
          after: after,
          action: action,
        );
      }
      if (mounted && successMessage != null) {
        _toast(successMessage);
      }
    } catch (e) {
      if (mounted) {
        _toast('Write failed: $e');
      }
    }
  }

  /// Shallow merge that simulates Firestore's `merge: true` semantics
  /// so the audit diff reflects what the doc will look like after the
  /// write.
  Map<String, dynamic> _mergeForDiff(
    Map<String, dynamic> before,
    Map<String, dynamic> payload,
  ) {
    final merged = Map<String, dynamic>.from(before);
    payload.forEach((key, value) {
      if (value is Map) {
        final existing = merged[key];
        final base = existing is Map
            ? Map<String, dynamic>.from(existing)
            : <String, dynamic>{};
        value.forEach((k, v) {
          if (v == null || v is FieldValue) {
            base.remove(k);
          } else {
            base[k.toString()] = v;
          }
        });
        merged[key] = base;
      } else if (value == null) {
        merged.remove(key);
      } else {
        merged[key] = value;
      }
    });
    return merged;
  }

  Future<bool> _askConfirm(_ConfirmSpec spec) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(spec.title),
        content: Text(spec.message),
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
            child: Text(spec.confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    if (target is _ShopTarget) {
      return _buildShopEditor();
    }
    return _buildDeviceEditor();
  }

  // ---------- shop editor ----------

  Widget _buildShopEditor() {
    final data = widget.data;
    final enabled = data['enabled'] as bool? ?? true;
    final expiresAt = _parseTs(data['licenseExpiresAt']);
    final flags = _readFlagMap(data['featureFlags']);
    final pinForced = _readFlagMap(data['pinForcedFlags']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPanel(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Shop enabled'),
            subtitle: const Text(
                'When off, every device attached to this shop is locked.'),
            value: enabled,
            onChanged: (v) => _update(
              {'enabled': v},
              action: v ? 'Enabled shop' : 'Disabled shop',
              successMessage: v ? 'Shop enabled' : 'Shop disabled',
              confirm: !v
                  ? const _ConfirmSpec(
                      title: 'Disable this shop?',
                      message:
                          'Every device attached to this shop will lock '
                              'immediately until you re-enable it.',
                      confirmLabel: 'Disable',
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: AppTokens.space1),
        AppPanel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('License expiry'),
            subtitle: Text(expiresAt == null
                ? 'No expiry set'
                : 'Expires ${_fmtDate(expiresAt)}'),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_calendar),
                  onPressed: () => _pickExpiry(
                    initial: expiresAt,
                    onChosen: (d) => _update(
                      {'licenseExpiresAt': d.toIso8601String()},
                      action: 'Set expiry to ${_fmtDate(d)}',
                      successMessage: 'Expiry set to ${_fmtDate(d)}',
                    ),
                  ),
                ),
                if (expiresAt != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _update(
                      {'licenseExpiresAt': null},
                      action: 'Cleared expiry',
                      successMessage: 'Expiry cleared',
                      confirm: expiresAt.isAfter(DateTime.now())
                          ? _ConfirmSpec(
                              title: 'Clear active expiry?',
                              message:
                                  'The current expiry is ${_fmtDate(expiresAt)} '
                                      '(in the future). Clearing it grants '
                                      'unlimited access.',
                              confirmLabel: 'Clear',
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTokens.space2),
        Text(
          'Feature toggles',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppTokens.space1),
        for (final f in FeatureKey.values)
          _FeatureTogglePanel(
            feature: f,
            enabled: flags[f] ?? true,
            pinForced: pinForced[f] ?? false,
            onToggle: (v) => _update(
              {
                'featureFlags': {f.key: v},
              },
              action: "${v ? 'Enabled' : 'Disabled'} feature '${_label(f)}'",
              successMessage:
                  "${_label(f)} ${v ? 'enabled' : 'disabled'}",
            ),
            onPinForce: (v) => _update(
              {
                'pinForcedFlags': {f.key: v},
              },
              action:
                  "${v ? 'Forced' : 'Unforced'} PIN for '${_label(f)}'",
              successMessage:
                  "PIN ${v ? 'required' : 'no longer forced'} for ${_label(f)}",
            ),
          ),
        const SizedBox(height: AppTokens.space2),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quotas',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTokens.space2),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _maxProductsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Max products',
                        helperText: 'Blank = no limit',
                      ),
                      onEditingComplete: () {
                        final v =
                            int.tryParse(_maxProductsController.text.trim());
                        _update(
                          {'maxProducts': v},
                          action: v == null
                              ? 'Removed max-products quota'
                              : 'Set max-products quota to $v',
                          successMessage: 'Quota saved',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  Expanded(
                    child: TextFormField(
                      controller: _maxSalesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Max sales per day',
                        helperText: 'Blank = no limit',
                      ),
                      onEditingComplete: () {
                        final v =
                            int.tryParse(_maxSalesController.text.trim());
                        _update(
                          {'maxSalesPerDay': v},
                          action: v == null
                              ? 'Removed max-sales-per-day quota'
                              : 'Set max-sales-per-day to $v',
                          successMessage: 'Quota saved',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space2),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notice',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTokens.space1),
              TextFormField(
                controller: _noticeController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Message shown on the license-lock screen',
                ),
              ),
              const SizedBox(height: AppTokens.space2),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => _update(
                    {'notice': _noticeController.text.trim()},
                    action: 'Updated license notice',
                    successMessage: 'Notice saved',
                  ),
                  child: const Text('Save notice'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- device editor ----------

  Widget _buildDeviceEditor() {
    final data = widget.data;
    final blocked = data['blocked'] as bool? ?? false;
    final expiresAt = _parseTs(data['expiresAt']);
    final overrides = _readFlagMap(data['featureOverrides']);
    final extras = context.appExtras;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPanel(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Block device',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: blocked ? extras.danger : null,
              ),
            ),
            subtitle: const Text(
                'Immediately locks the app on this install regardless of shop.'),
            value: blocked,
            onChanged: (v) => _update(
              {'blocked': v},
              action: v ? 'Blocked device' : 'Unblocked device',
              successMessage: v ? 'Device blocked' : 'Device unblocked',
              confirm: v
                  ? const _ConfirmSpec(
                      title: 'Block this device?',
                      message:
                          'The app on this device will lock immediately '
                              'and stay locked until you unblock it.',
                      confirmLabel: 'Block',
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: AppTokens.space1),
        AppPanel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Device-specific expiry'),
            subtitle: Text(expiresAt == null
                ? 'Falls back to shop expiry'
                : 'Expires ${_fmtDate(expiresAt)}'),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_calendar),
                  onPressed: () => _pickExpiry(
                    initial: expiresAt,
                    onChosen: (d) => _update(
                      {'expiresAt': d.toIso8601String()},
                      action: 'Set device expiry to ${_fmtDate(d)}',
                      successMessage: 'Device expiry set',
                    ),
                  ),
                ),
                if (expiresAt != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _update(
                      {'expiresAt': null},
                      action: 'Cleared device expiry',
                      successMessage: 'Device expiry cleared',
                      confirm: expiresAt.isAfter(DateTime.now())
                          ? _ConfirmSpec(
                              title: 'Clear active device expiry?',
                              message:
                                  'Current expiry is ${_fmtDate(expiresAt)}. '
                                      'Clearing falls back to the shop expiry.',
                              confirmLabel: 'Clear',
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTokens.space2),
        Text(
          'Feature overrides',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          'Three states: inherit from shop, force enabled, or force disabled.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: extras.muted),
        ),
        const SizedBox(height: AppTokens.space1),
        for (final f in FeatureKey.values)
          _DeviceOverrideRow(
            feature: f,
            value: overrides[f],
            onChanged: (v) => _update(
              {
                'featureOverrides': {f.key: v},
              },
              action:
                  "Override '${_label(f)}' \u2192 ${v ? 'forced on' : 'forced off'}",
              successMessage:
                  "${_label(f)} overridden to ${v ? 'on' : 'off'}",
            ),
            onClear: () => _update(
              {
                'featureOverrides': {f.key: FieldValue.delete()},
              },
              action: "Cleared override for '${_label(f)}' (inherit)",
              successMessage: "${_label(f)} now inherits from shop",
            ),
          ),
      ],
    );
  }

  // ---------- helpers ----------

  Future<void> _pickExpiry({
    required DateTime? initial,
    required void Function(DateTime) onChosen,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    // Expire at end-of-day so the admin's chosen date stays usable.
    final endOfDay = DateTime(
      picked.year,
      picked.month,
      picked.day,
      23,
      59,
      59,
    );
    onChosen(endOfDay);
  }

  static Map<FeatureKey, bool> _readFlagMap(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <FeatureKey, bool>{};
    raw.forEach((k, v) {
      if (k is String && v is bool) {
        final fk = FeatureKey.fromString(k);
        if (fk != null) result[fk] = v;
      }
    });
    return result;
  }

  static DateTime? _parseTs(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String _fmtDate(DateTime at) {
    final y = at.year.toString().padLeft(4, '0');
    final m = at.month.toString().padLeft(2, '0');
    final d = at.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _FeatureTogglePanel extends StatelessWidget {
  final FeatureKey feature;
  final bool enabled;
  final bool pinForced;
  final ValueChanged<bool> onToggle;
  final ValueChanged<bool> onPinForce;

  const _FeatureTogglePanel({
    required this.feature,
    required this.enabled,
    required this.pinForced,
    required this.onToggle,
    required this.onPinForce,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppTokens.space1),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _label(feature),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            value: enabled,
            onChanged: onToggle,
          ),
          Divider(height: 1, color: extras.border),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Force PIN protection'),
            subtitle: const Text(
                'Require PIN for this feature regardless of device preference.'),
            value: pinForced,
            onChanged: onPinForce,
          ),
        ],
      ),
    );
  }
}

class _DeviceOverrideRow extends StatelessWidget {
  final FeatureKey feature;
  final bool? value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onClear;

  const _DeviceOverrideRow({
    required this.feature,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    String label;
    Color tone;
    if (value == null) {
      label = 'Inherit';
      tone = extras.muted;
    } else if (value == true) {
      label = 'Forced on';
      tone = extras.success;
    } else {
      label = 'Forced off';
      tone = extras.danger;
    }
    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppTokens.space1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _label(feature),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(label, style: TextStyle(color: tone)),
          const SizedBox(width: AppTokens.space2),
          Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: 'Force off',
                icon: const Icon(Icons.block),
                onPressed: () => onChanged(false),
              ),
              IconButton(
                tooltip: 'Inherit',
                icon: const Icon(Icons.remove),
                onPressed: onClear,
              ),
              IconButton(
                tooltip: 'Force on',
                icon: const Icon(Icons.check),
                onPressed: () => onChanged(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Spec for a confirmation dialog that gates a destructive update.
class _ConfirmSpec {
  final String title;
  final String message;
  final String confirmLabel;

  const _ConfirmSpec({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });
}

String _label(FeatureKey feature) {
  switch (feature) {
    case FeatureKey.sales:
      return 'Sales';
    case FeatureKey.inventoryEdit:
      return 'Inventory editing';
    case FeatureKey.reports:
      return 'Reports';
    case FeatureKey.printing:
      return 'Receipt printing';
    case FeatureKey.cloudSync:
      return 'Cloud sync';
    case FeatureKey.lanSync:
      return 'LAN / Wi-Fi Direct sync';
  }
}
