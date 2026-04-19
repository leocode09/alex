import 'package:flutter/material.dart';

import '../../../design_system/widgets/app_badge.dart';
import '../admin_heuristics.dart';


/// Compact pill that shows the derived status for a shop or device.
///
/// For a shop, pass the raw doc data. For a device, set [isDevice]=true.
/// For an "outdated app version" badge, pass [outdated]=true and we
/// render a single warning badge on top of the derived status.
class AdminStatusBadge extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDevice;
  final bool outdated;

  const AdminStatusBadge({
    super.key,
    required this.data,
    this.isDevice = false,
    this.outdated = false,
  });

  @override
  Widget build(BuildContext context) {
    final labels = <_BadgeData>[];

    if (isDevice) {
      final status = AdminHeuristics.deviceStatus(data);
      labels.add(_deviceBadge(status, data));
    } else {
      final status = AdminHeuristics.shopStatus(data);
      labels.add(_shopBadge(status, data));
    }

    if (outdated) {
      labels.add(const _BadgeData('Outdated', AppBadgeTone.warning));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final b in labels) AppBadge(label: b.label, tone: b.tone),
      ],
    );
  }

  static _BadgeData _shopBadge(ShopStatus status, Map<String, dynamic> data) {
    switch (status) {
      case ShopStatus.active:
        return const _BadgeData('Active', AppBadgeTone.success);
      case ShopStatus.disabled:
        return const _BadgeData('Disabled', AppBadgeTone.danger);
      case ShopStatus.expiringSoon:
        final d = AdminHeuristics.daysUntilExpiry(data) ?? 0;
        return _BadgeData(
          d <= 0 ? 'Expires today' : 'Expires in ${d}d',
          AppBadgeTone.warning,
        );
      case ShopStatus.expired:
        final d = AdminHeuristics.daysUntilExpiry(data) ?? 0;
        return _BadgeData(
          d <= -1 ? 'Expired ${-d}d ago' : 'Expired',
          AppBadgeTone.danger,
        );
    }
  }

  static _BadgeData _deviceBadge(
      DeviceStatus status, Map<String, dynamic> data) {
    switch (status) {
      case DeviceStatus.online:
        return const _BadgeData('Online', AppBadgeTone.success);
      case DeviceStatus.offline:
        final d = AdminHeuristics.daysSinceLastSeen(data);
        if (d == null) return const _BadgeData('Never seen', AppBadgeTone.neutral);
        return _BadgeData('Offline ${d}d', AppBadgeTone.neutral);
      case DeviceStatus.blocked:
        return const _BadgeData('Blocked', AppBadgeTone.danger);
      case DeviceStatus.expiringSoon:
        final d = AdminHeuristics.daysUntilExpiry(data, deviceScoped: true) ?? 0;
        return _BadgeData(
          d <= 0 ? 'Expires today' : 'Expires in ${d}d',
          AppBadgeTone.warning,
        );
      case DeviceStatus.expired:
        return const _BadgeData('Expired', AppBadgeTone.danger);
    }
  }
}

class _BadgeData {
  final String label;
  final AppBadgeTone tone;
  const _BadgeData(this.label, this.tone);
}
