import 'package:flutter/material.dart';

import '../models/license_policy.dart';
import '../services/admin/license_service.dart';

/// Helper for feature gating at call sites.
///
/// Synchronous usage (e.g. inside a service that has no BuildContext):
///   if (!LicenseGate.isAllowed(FeatureKey.cloudSync)) return;
///
/// UI usage, with a blocking dialog shown to the user:
///   if (!await LicenseGate.ensure(context, FeatureKey.createSale)) return;
class LicenseGate {
  const LicenseGate._();

  /// Synchronous check against the latest known policy. Safe to call
  /// even before any stream subscription exists — returns true when the
  /// policy is not yet known so the app stays usable offline.
  static bool isAllowed(FeatureKey feature) {
    final policy = LicenseService().current;
    if (policy.blockReason() != null) {
      return false;
    }
    return policy.isFeatureEnabled(feature);
  }

  /// Returns the latest [LicensePolicy].
  static LicensePolicy get policy => LicenseService().current;

  /// Shows a themed dialog explaining the block and returns true when
  /// the feature is allowed, false otherwise.
  static Future<bool> ensure(
    BuildContext context,
    FeatureKey feature, {
    String? featureLabel,
  }) async {
    final policy = LicenseService().current;
    final block = policy.blockReason();
    if (block != null) {
      if (context.mounted) {
        await _showBlockDialog(context, block.title, block.message);
      }
      return false;
    }
    if (policy.isFeatureEnabled(feature)) {
      return true;
    }
    final label = featureLabel ?? _defaultLabel(feature);
    if (context.mounted) {
      await _showBlockDialog(
        context,
        'Feature disabled',
        '"$label" has been disabled by the administrator. Contact support '
            'if you need access.',
      );
    }
    return false;
  }

  static Future<void> _showBlockDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  static String _defaultLabel(FeatureKey feature) {
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
        return 'LAN sync';
    }
  }
}
