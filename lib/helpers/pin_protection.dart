import 'package:flutter/material.dart';
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
}
