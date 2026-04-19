import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/license_policy.dart';
import '../../../../providers/admin_auth_provider.dart';
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

  Future<void> _update(Map<String, dynamic> payload) async {
    try {
      await _ref().set(payload, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Write failed: $e')),
        );
      }
    }
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
            onChanged: (v) => _update({'enabled': v}),
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
                    onChosen: (d) => _update({
                      'licenseExpiresAt': d.toIso8601String(),
                    }),
                  ),
                ),
                if (expiresAt != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _update({'licenseExpiresAt': null}),
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
            onToggle: (v) => _update({
              'featureFlags': {f.key: v},
            }),
            onPinForce: (v) => _update({
              'pinForcedFlags': {f.key: v},
            }),
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
                      onEditingComplete: () => _update({
                        'maxProducts': int.tryParse(
                          _maxProductsController.text.trim(),
                        ),
                      }),
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
                      onEditingComplete: () => _update({
                        'maxSalesPerDay': int.tryParse(
                          _maxSalesController.text.trim(),
                        ),
                      }),
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
                  onPressed: () => _update({
                    'notice': _noticeController.text.trim(),
                  }),
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
            onChanged: (v) => _update({'blocked': v}),
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
                    onChosen: (d) =>
                        _update({'expiresAt': d.toIso8601String()}),
                  ),
                ),
                if (expiresAt != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _update({'expiresAt': null}),
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
            onChanged: (v) => _update({
              'featureOverrides': {f.key: v},
            }),
            onClear: () => _update({
              'featureOverrides': {f.key: FieldValue.delete()},
            }),
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
