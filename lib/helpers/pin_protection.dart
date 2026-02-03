import 'package:flutter/material.dart';
import '../services/pin_service.dart';
import '../ui/pages/auth/pin_entry_page.dart';

class PinProtection {
  static Future<bool> requirePin(BuildContext context, {
    String title = 'Authentication Required',
    String subtitle = 'Enter your PIN to continue',
  }) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PinEntryPage(
          title: title,
          subtitle: subtitle,
          canGoBack: true,
        ),
        fullscreenDialog: true,
      ),
    );
    return result ?? false;
  }

  static Future<bool> requirePinIfNeeded(
    BuildContext context, {
    required Future<bool> Function() isRequired,
    String title = 'Authentication Required',
    String subtitle = 'Enter your PIN to continue',
  }) async {
    final pinService = PinService();
    final isPinSet = await pinService.isPinSet();
    if (!isPinSet) {
      return true;
    }

    final required = await isRequired();
    if (!required) {
      return true;
    }

    return requirePin(
      context,
      title: title,
      subtitle: subtitle,
    );
  }
}
