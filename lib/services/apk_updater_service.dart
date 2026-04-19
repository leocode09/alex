import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles full-APK over-the-air updates for Android devices that receive the
/// app outside the Play Store (direct APK share, LAN, email, etc.).
///
/// The service expects a small JSON "manifest" hosted anywhere reachable over
/// HTTPS (GitHub Releases, Firebase Storage, a static website, etc.) shaped
/// like:
///
///   {
///     "versionCode": 2,
///     "versionName": "1.0.1",
///     "apkUrl": "https://example.com/ALEX-1.0.1.apk",
///     "sha256": "optional-hex-digest",
///     "releaseNotes": "- fixed printer auto-reconnect\n- faster startup",
///     "mandatory": false,
///     "minSupportedVersionCode": 1
///   }
///
/// Only `versionCode`, `versionName`, and `apkUrl` are required. Everything
/// else is optional metadata the UI can surface to the user.
///
/// Shorebird (already wired up in `main.dart`) handles instant Dart-only
/// patches. This service complements it for native / asset / plugin changes,
/// which Shorebird cannot ship.
class ApkUpdaterService {
  ApkUpdaterService._();
  static final ApkUpdaterService instance = ApkUpdaterService._();

  /// Override the compiled-in default at runtime. Stored in SharedPreferences
  /// so power users / support can repoint the app without a reinstall.
  static const _manifestUrlPrefKey = 'apk_updater.manifest_url';
  static const _lastCheckPrefKey = 'apk_updater.last_check_ms';
  static const _skippedVersionPrefKey = 'apk_updater.skipped_version_code';

  /// Default manifest URL. Points at the "latest" GitHub Release asset so any
  /// published release automatically becomes the update target. Override at
  /// runtime via [setManifestUrl] (Settings -> long-press "Check for Updates")
  /// for staging channels or self-hosted builds.
  static const String defaultManifestUrl =
      'https://github.com/leocode09/alex/releases/latest/download/update.json';

  Future<String?> getManifestUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_manifestUrlPrefKey);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    if (defaultManifestUrl.trim().isNotEmpty) {
      return defaultManifestUrl.trim();
    }
    return null;
  }

  Future<void> setManifestUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_manifestUrlPrefKey, url.trim());
  }

  Future<DateTime?> lastCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastCheckPrefKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _markChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastCheckPrefKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> skipVersion(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_skippedVersionPrefKey, versionCode);
  }

  Future<int?> skippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_skippedVersionPrefKey);
  }

  /// Fetches the manifest and returns an [UpdateCheckResult]. Never throws;
  /// network / parse errors come back as [UpdateCheckStatus.error].
  Future<UpdateCheckResult> checkForUpdate({bool ignoreSkip = false}) async {
    if (kIsWeb || !Platform.isAndroid) {
      return const UpdateCheckResult(status: UpdateCheckStatus.unsupported);
    }
    final url = await getManifestUrl();
    if (url == null) {
      return const UpdateCheckResult(status: UpdateCheckStatus.notConfigured);
    }

    try {
      final response = await http
          .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.error,
          errorMessage: 'HTTP ${response.statusCode}',
        );
      }
      final body = response.body.trim();
      if (body.isEmpty) {
        return const UpdateCheckResult(
          status: UpdateCheckStatus.error,
          errorMessage: 'Empty manifest',
        );
      }
      final Map<String, dynamic> json = jsonDecode(body) as Map<String, dynamic>;
      final manifest = UpdateManifest.fromJson(json);
      await _markChecked();

      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;

      if (manifest.versionCode <= currentCode) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.upToDate,
          manifest: manifest,
          currentVersionCode: currentCode,
          currentVersionName: info.version,
        );
      }

      if (!ignoreSkip) {
        final skipped = await skippedVersion();
        if (skipped != null && skipped == manifest.versionCode && !manifest.mandatory) {
          return UpdateCheckResult(
            status: UpdateCheckStatus.skipped,
            manifest: manifest,
            currentVersionCode: currentCode,
            currentVersionName: info.version,
          );
        }
      }

      return UpdateCheckResult(
        status: UpdateCheckStatus.updateAvailable,
        manifest: manifest,
        currentVersionCode: currentCode,
        currentVersionName: info.version,
      );
    } on TimeoutException {
      return const UpdateCheckResult(
        status: UpdateCheckStatus.error,
        errorMessage: 'Timed out while fetching update manifest',
      );
    } on SocketException catch (e) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.error,
        errorMessage: 'Network error: ${e.message}',
      );
    } on FormatException catch (e) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.error,
        errorMessage: 'Malformed manifest: ${e.message}',
      );
    } on Object catch (e) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Downloads the APK to app-scoped external storage, streaming progress via
  /// [onProgress] (0.0 .. 1.0). Returns the file on success.
  Future<File> downloadApk(
    UpdateManifest manifest, {
    void Function(double progress, int received, int total)? onProgress,
    http.Client? client,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('APK install is only supported on Android');
    }

    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    try {
      final request = http.Request('GET', Uri.parse(manifest.apkUrl));
      final response = await httpClient.send(request);
      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to download APK: HTTP ${response.statusCode}',
          uri: Uri.parse(manifest.apkUrl),
        );
      }

      final dir = await _downloadDirectory();
      final safeName =
          'alex-${manifest.versionCode}-${DateTime.now().millisecondsSinceEpoch}.apk';
      final file = File('${dir.path}/$safeName');
      final sink = file.openWrite();

      final total = response.contentLength ?? 0;
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0 && onProgress != null) {
            onProgress(received / total, received, total);
          } else if (onProgress != null) {
            onProgress(0, received, 0);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      return file;
    } finally {
      if (ownsClient) {
        httpClient.close();
      }
    }
  }

  Future<Directory> _downloadDirectory() async {
    final external = await getExternalStorageDirectory();
    final dir = Directory(
      '${(external ?? await getApplicationSupportDirectory()).path}/updates',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Triggers Android's package installer for [apk]. Requires the user to
  /// grant "Install unknown apps" the first time, which [ensureInstallPermission]
  /// handles.
  Future<InstallLaunchResult> launchInstaller(File apk) async {
    if (!Platform.isAndroid) {
      return const InstallLaunchResult(
        launched: false,
        message: 'Install only supported on Android',
      );
    }
    final granted = await ensureInstallPermission();
    if (!granted) {
      return const InstallLaunchResult(
        launched: false,
        message:
            'Permission to install unknown apps was not granted. Enable it in system settings and try again.',
      );
    }
    final result = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    final ok = result.type == ResultType.done;
    return InstallLaunchResult(
      launched: ok,
      message: ok ? 'Installer launched' : result.message,
    );
  }

  /// Requests REQUEST_INSTALL_PACKAGES. Returns true if already granted or
  /// granted by the user, false otherwise.
  Future<bool> ensureInstallPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.requestInstallPackages.status;
    if (status.isGranted) return true;
    final result = await Permission.requestInstallPackages.request();
    return result.isGranted;
  }
}

enum UpdateCheckStatus {
  unsupported,
  notConfigured,
  upToDate,
  updateAvailable,
  skipped,
  error,
}

@immutable
class UpdateCheckResult {
  final UpdateCheckStatus status;
  final UpdateManifest? manifest;
  final int? currentVersionCode;
  final String? currentVersionName;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    this.manifest,
    this.currentVersionCode,
    this.currentVersionName,
    this.errorMessage,
  });

  bool get hasUpdate => status == UpdateCheckStatus.updateAvailable;
}

@immutable
class UpdateManifest {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String? sha256;
  final String? releaseNotes;
  final bool mandatory;
  final int? minSupportedVersionCode;

  const UpdateManifest({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    this.sha256,
    this.releaseNotes,
    this.mandatory = false,
    this.minSupportedVersionCode,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final rawCode = json['versionCode'];
    final versionCode = rawCode is int
        ? rawCode
        : int.tryParse('${rawCode ?? ''}') ?? 0;
    final versionName = (json['versionName'] ?? '').toString();
    final apkUrl = (json['apkUrl'] ?? json['url'] ?? '').toString();
    if (versionCode <= 0 || versionName.isEmpty || apkUrl.isEmpty) {
      throw const FormatException(
        'Manifest must contain versionCode, versionName, and apkUrl',
      );
    }
    return UpdateManifest(
      versionCode: versionCode,
      versionName: versionName,
      apkUrl: apkUrl,
      sha256: json['sha256']?.toString(),
      releaseNotes: json['releaseNotes']?.toString(),
      mandatory: json['mandatory'] == true,
      minSupportedVersionCode: json['minSupportedVersionCode'] is int
          ? json['minSupportedVersionCode'] as int
          : null,
    );
  }
}

@immutable
class InstallLaunchResult {
  final bool launched;
  final String message;
  const InstallLaunchResult({required this.launched, required this.message});
}
