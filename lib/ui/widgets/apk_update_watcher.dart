import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/apk_updater_service.dart';
import '../design_system/app_theme_extensions.dart';

/// Wraps the app and checks for a new APK build shortly after startup.
/// Shows a dialog with release notes + "Update now" when a newer version is
/// available. Silent on no-op / error / offline.
class ApkUpdateWatcher extends StatefulWidget {
  final Widget child;

  /// Delay before the first check so we don't race with heavy startup work
  /// (Firebase init, font loading, router build).
  final Duration initialDelay;

  const ApkUpdateWatcher({
    super.key,
    required this.child,
    this.initialDelay = const Duration(seconds: 3),
  });

  @override
  State<ApkUpdateWatcher> createState() => _ApkUpdateWatcherState();
}

class _ApkUpdateWatcherState extends State<ApkUpdateWatcher> {
  Timer? _bootTimer;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      _bootTimer = Timer(widget.initialDelay, _runCheck);
    }
  }

  @override
  void dispose() {
    _bootTimer?.cancel();
    super.dispose();
  }

  Future<void> _runCheck() async {
    if (!mounted || _dialogShown) return;
    final result = await ApkUpdaterService.instance.checkForUpdate();
    if (!mounted || !result.hasUpdate || result.manifest == null) return;
    _dialogShown = true;
    await showUpdateDialog(context, result);
    _dialogShown = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Public entry-point so Settings → "Check for updates" can reuse the same UI.
Future<void> showUpdateDialog(
  BuildContext context,
  UpdateCheckResult result,
) async {
  final manifest = result.manifest;
  if (manifest == null) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: !manifest.mandatory,
    builder: (_) => _UpdateDialog(result: result),
  );
}

class _UpdateDialog extends StatefulWidget {
  final UpdateCheckResult result;
  const _UpdateDialog({required this.result});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  bool _downloading = false;
  bool _launching = false;
  String? _error;
  File? _downloaded;

  UpdateManifest get manifest => widget.result.manifest!;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final file = await ApkUpdaterService.instance.downloadApk(
        manifest,
        onProgress: (p, _, __) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _downloaded = file;
        _downloading = false;
      });
      await _launchInstaller(file);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _launchInstaller(File file) async {
    setState(() => _launching = true);
    final outcome = await ApkUpdaterService.instance.launchInstaller(file);
    if (!mounted) return;
    setState(() {
      _launching = false;
      if (!outcome.launched) {
        _error = outcome.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.appExtras;
    final current = widget.result.currentVersionName ?? '-';
    final target = manifest.versionName;
    final notes = manifest.releaseNotes?.trim();
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update_alt_rounded,
              color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          const Expanded(child: Text('Update available')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A new version of ALEX is ready to install.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _VersionRow(label: 'Installed', value: current, muted: extras.muted),
            _VersionRow(label: 'New', value: target, muted: extras.muted),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text("What's new",
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(notes, style: theme.textTheme.bodySmall),
            ],
            if (_downloading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text(
                _progress == null
                    ? 'Downloading…'
                    : 'Downloading ${((_progress ?? 0) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(color: extras.muted),
              ),
            ],
            if (_launching) ...[
              const SizedBox(height: 16),
              Text('Opening installer…',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: extras.muted)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: extras.danger),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!manifest.mandatory && !_downloading && _downloaded == null)
          TextButton(
            onPressed: () async {
              await ApkUpdaterService.instance.skipVersion(manifest.versionCode);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Skip this version'),
          ),
        if (!manifest.mandatory && !_downloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
        if (_downloaded != null)
          FilledButton(
            onPressed: _launching
                ? null
                : () => _launchInstaller(_downloaded!),
            child: const Text('Install'),
          )
        else
          FilledButton(
            onPressed: _downloading ? null : _startDownload,
            child: Text(_downloading ? 'Downloading…' : 'Update now'),
          ),
      ],
    );
  }
}

class _VersionRow extends StatelessWidget {
  final String label;
  final String value;
  final Color muted;
  const _VersionRow({
    required this.label,
    required this.value,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
