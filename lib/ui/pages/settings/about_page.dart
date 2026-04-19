import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../../../config/app_share_config.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  Future<_AboutInfo>? _info;

  @override
  void initState() {
    super.initState();
    _info = _loadInfo();
  }

  Future<_AboutInfo> _loadInfo() async {
    PackageInfo? packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      // PackageInfo is not available on some platforms (e.g. tests, desktop CI).
    }

    int? patchNumber;
    if (!kIsWeb) {
      try {
        final updater = ShorebirdUpdater();
        if (updater.isAvailable) {
          final patch = await updater.readCurrentPatch();
          patchNumber = patch?.number;
        }
      } catch (_) {
        // Shorebird optional — ignore failures.
      }
    }

    return _AboutInfo(
      appName: packageInfo?.appName ?? AppShareConfig.appName,
      version: packageInfo?.version ?? '1.0.1',
      buildNumber: packageInfo?.buildNumber ?? '',
      packageName: packageInfo?.packageName ?? '',
      patchNumber: patchNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.appExtras;

    return AppPageScaffold(
      title: 'About',
      scrollable: true,
      child: FutureBuilder<_AboutInfo>(
        future: _info,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final info = snapshot.data ??
              _AboutInfo(
                appName: AppShareConfig.appName,
                version: '1.0.1',
                buildNumber: '',
                packageName: '',
                patchNumber: null,
              );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPanel(
                padding: const EdgeInsets.all(AppTokens.space4),
                child: Column(
                  children: [
                    GestureDetector(
                      onLongPress: () => context.push('/admin-login'),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusL),
                        child: Image.asset(
                          'assets/logo.jpg',
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(30),
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radiusL),
                            ),
                            child: Icon(
                              Icons.point_of_sale_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space3),
                    Text(
                      info.appName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _versionLine(info),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: extras.muted,
                        fontFamily: 'IBMPlexMono',
                      ),
                    ),
                    const SizedBox(height: AppTokens.space3),
                    Text(
                      'A production-ready Point of Sale system for '
                      'small retailers — offline first, sync anywhere.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: extras.muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space4),
              const _SectionHeader(label: 'Build details'),
              const SizedBox(height: AppTokens.space2),
              AppPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Version',
                      value: info.version.isEmpty ? '—' : info.version,
                      onTap: info.version.isEmpty
                          ? null
                          : () => _copy(context, info.version, 'Version copied'),
                    ),
                    _divider(context),
                    _InfoRow(
                      label: 'Build',
                      value: info.buildNumber.isEmpty ? '—' : info.buildNumber,
                      onTap: info.buildNumber.isEmpty
                          ? null
                          : () =>
                              _copy(context, info.buildNumber, 'Build copied'),
                    ),
                    _divider(context),
                    _InfoRow(
                      label: 'Patch',
                      value: info.patchNumber == null
                          ? 'none'
                          : '#${info.patchNumber}',
                    ),
                    _divider(context),
                    _InfoRow(
                      label: 'Package',
                      value: info.packageName.isEmpty ? '—' : info.packageName,
                      onTap: info.packageName.isEmpty
                          ? null
                          : () => _copy(
                                context,
                                info.packageName,
                                'Package name copied',
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space4),
              const _SectionHeader(label: 'Links'),
              const SizedBox(height: AppTokens.space2),
              AppPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _LinkRow(
                      icon: Icons.help_outline_rounded,
                      title: 'Help Center',
                      subtitle: 'FAQ and support',
                      onTap: () => context.push('/help'),
                    ),
                    _divider(context),
                    _LinkRow(
                      icon: Icons.qr_code_2_rounded,
                      title: 'Share this app',
                      subtitle: 'QR code and download link',
                      onTap: () => context.push('/share-app'),
                    ),
                    _divider(context),
                    _LinkRow(
                      icon: Icons.description_outlined,
                      title: 'Privacy & terms',
                      subtitle: 'Open legal notice',
                      onTap: () => _showLegalSheet(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space4),
              Center(
                child: Text(
                  '© ${DateTime.now().year} ${AppShareConfig.appName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: extras.muted,
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.space4),
            ],
          );
        },
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: AppTokens.border,
      color: context.appExtras.border,
    );
  }

  String _versionLine(_AboutInfo info) {
    final buf = StringBuffer('v${info.version}');
    if (info.buildNumber.isNotEmpty) {
      buf.write(' (${info.buildNumber})');
    }
    if (info.patchNumber != null) {
      buf.write(' · patch #${info.patchNumber}');
    }
    return buf.toString();
  }

  Future<void> _copy(
    BuildContext context,
    String value,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showLegalSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space3,
              0,
              AppTokens.space3,
              AppTokens.space4,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy & terms',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    'ALEX stores your business data locally on this device. '
                    'Nothing leaves the device unless you explicitly enable '
                    'Cloud Sync, LAN sync or Wi-Fi Direct sync in Settings. '
                    'When cloud sync is enabled, data is partitioned by your '
                    'shop code and transmitted over an encrypted connection '
                    'to Firestore.\n\n'
                    'Admin tooling (device registration, heartbeat, usage '
                    'stats) is used only to enforce licensing and report '
                    'app health. Sales and customer records are never used '
                    'for advertising.\n\n'
                    'By using ALEX you agree to use it in compliance with '
                    'local tax, privacy and consumer-protection laws.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AboutInfo {
  _AboutInfo({
    required this.appName,
    required this.version,
    required this.buildNumber,
    required this.packageName,
    required this.patchNumber,
  });

  final String appName;
  final String version;
  final String buildNumber;
  final String packageName;
  final int? patchNumber;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.appExtras.muted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.appExtras;
    return ListTile(
      title: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: extras.muted,
              fontFamily: 'IBMPlexMono',
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.copy_rounded,
              size: 14,
              color: extras.muted,
            ),
          ],
        ],
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      onTap: onTap,
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.appExtras;
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: extras.muted,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: extras.muted,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
    );
  }
}
