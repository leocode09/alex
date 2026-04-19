import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/app_share_config.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

/// Shows a QR code + URL so nearby devices can scan and install the app,
/// and offers native share / copy-link actions for remote sharing.
class ShareAppPage extends StatelessWidget {
  const ShareAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.appExtras;
    const url = AppShareConfig.downloadUrl;

    return AppPageScaffold(
      title: 'Share App',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPanel(
            padding: const EdgeInsets.all(AppTokens.space4),
            child: Column(
              children: [
                Text(
                  AppShareConfig.appName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan to download',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: extras.muted,
                  ),
                ),
                const SizedBox(height: AppTokens.space4),
                _QrCard(data: url),
                const SizedBox(height: AppTokens.space4),
                SelectableText(
                  url,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'IBMPlexMono',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyLink(context, url),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy link'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _shareLink(context),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
          AppPanel(
            padding: const EdgeInsets.all(AppTokens.space3),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: extras.muted),
                const SizedBox(width: AppTokens.space2),
                Expanded(
                  child: Text(
                    'Point a phone camera at the QR code to open the download page.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: extras.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyLink(BuildContext context, String url) async {
    await Clipboard.setData(const ClipboardData(text: AppShareConfig.downloadUrl));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download link copied')),
    );
  }

  Future<void> _shareLink(BuildContext context) async {
    // share_plus is unsupported on Windows/Linux desktop; fall back to copy.
    final canNativeShare = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (canNativeShare) {
      await Share.share(AppShareConfig.shareMessage);
      return;
    }
    await _copyLink(context, AppShareConfig.downloadUrl);
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    // QR always renders on white with black modules for best camera contrast,
    // regardless of app theme.
    return Container(
      padding: const EdgeInsets.all(AppTokens.space3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        border: Border.all(color: extras.borderStrong, width: AppTokens.border),
      ),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: 220,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    );
  }
}
