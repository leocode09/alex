import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OTA-style self-updates (MarkEase / DimeSchool protocol): on cold start the
/// app silently checks a published manifest for a newer build, downloads it in
/// the background, verifies its SHA-256 against the manifest, and surfaces an
/// Install banner when ready. Failures at any step are swallowed — the app
/// always keeps running the current build.
///
/// Android only. The manifest lives on GitHub Releases as
/// `releases/latest/download/manifest.json` (see scripts/make_update_manifest.mjs).
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const _stagedMetaName = 'staged.json';
  static const _appliedMetaName = 'applied.json';
  static const _manifestUrlPrefKey = 'ota.manifest_url';
  static const _lastCheckPrefKey = 'ota.last_check_ms';
  static const _legacyManifestUrlPrefKey = 'apk_updater.manifest_url';

  static const String defaultManifestUrl =
      'https://github.com/leocode09/alex/releases/latest/download/manifest.json';

  static const _reapplyCooldown = Duration(hours: 24);

  final ValueNotifier<ReadyUpdate?> ready = ValueNotifier<ReadyUpdate?>(null);

  bool _busy = false;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  bool get _enabled => kReleaseMode;

  Future<String?> getManifestUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_manifestUrlPrefKey) ??
        prefs.getString(_legacyManifestUrlPrefKey);
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

  /// Silently check the manifest and stage a newer build if one is published.
  Future<void> start() async {
    if (kIsWeb || !_supported || !_enabled || _busy) return;
    await _runCheck();
  }

  /// Manual check from Settings — allowed in debug builds too.
  ///
  /// Always re-fetches the manifest when [force] is true, even if an older
  /// APK is already staged, so a phone stuck on e.g. 1.0.6 can pick up 1.0.7.
  Future<UpdateCheckResult> checkForUpdate({bool force = true}) async {
    if (kIsWeb || !_supported) {
      return const UpdateCheckResult(status: UpdateCheckStatus.unsupported);
    }
    final url = await getManifestUrl();
    if (url == null || url.isEmpty) {
      return const UpdateCheckResult(status: UpdateCheckStatus.notConfigured);
    }

    try {
      if (!force && ready.value != null) {
        await _markChecked();
        return UpdateCheckResult(
          status: UpdateCheckStatus.updateReady,
          version: ready.value!.version,
        );
      }

      if (_busy) {
        // A cold-start check may already be downloading; surface whatever is
        // staged so Settings isn't a hard error mid-download.
        if (ready.value != null) {
          return UpdateCheckResult(
            status: UpdateCheckStatus.updateReady,
            version: ready.value!.version,
          );
        }
        return const UpdateCheckResult(
          status: UpdateCheckStatus.error,
          errorMessage: 'Update check already in progress',
        );
      }

      await _runCheck(force: force);
      await _markChecked();

      final staged = ready.value;
      if (staged != null) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.updateReady,
          version: staged.version,
        );
      }

      return const UpdateCheckResult(status: UpdateCheckStatus.upToDate);
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
    } on Object catch (e) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _runCheck({bool force = false}) async {
    if (!_supported || _busy) return;
    if (!force && !_enabled) return;

    _busy = true;
    try {
      await _restoreStagedBanner();
      await _checkAndStage();
    } catch (e) {
      debugPrint('[update] check failed: $e');
      if (force) rethrow;
    } finally {
      _busy = false;
    }
  }

  Future<void> applyNow() async {
    final update = ready.value;
    if (update == null) return;
    try {
      final granted = await _ensureInstallPermission();
      if (!granted) {
        debugPrint('[update] install permission not granted');
        return;
      }
      await OpenFilex.open(
        update.filePath,
        type: 'application/vnd.android.package-archive',
      );
    } catch (e) {
      debugPrint('[update] apply failed: $e');
    }
  }

  Future<void> _restoreStagedBanner() async {
    try {
      final dir = await _updatesDir();
      final metaFile = File('${dir.path}/$_stagedMetaName');
      if (!metaFile.existsSync()) return;
      final meta = jsonDecode(await metaFile.readAsString());
      if (meta is! Map<String, dynamic>) return;
      final version = meta['version'];
      final fileName = meta['file'];
      final hash = meta['sha256'];
      if (version is! String || fileName is! String || hash is! String) return;
      final file = File('${dir.path}/$fileName');
      if (!file.existsSync()) return;
      if (compareVersions(version, await _currentVersion()) <= 0) return;
      if (await _sha256Base64Url(file.path) != hash) return;
      ready.value = ReadyUpdate(version: version, filePath: file.path);
      debugPrint('[update] restored staged $version from a previous session');
    } catch (e) {
      debugPrint('[update] staged restore failed: $e');
    }
  }

  Future<void> _checkAndStage() async {
    final current = await _currentVersion();
    final manifest = await _fetchManifest(current);
    if (manifest == null) return;

    final dir = await _updatesDir();
    if (compareVersions(manifest.version, current) <= 0) {
      await _deleteStagedFiles(dir, alsoApplied: true);
      ready.value = null;
      return;
    }

    if (await _recentlyApplied(dir, manifest.version)) {
      debugPrint(
        '[update] ${manifest.version} was already applied but the app still '
        'reports $current — skipping until cooldown expires',
      );
      return;
    }

    final asset = manifest.asset;
    final target = File('${dir.path}/ALEX-${asset.key}.apk');

    // If a newer release is published while an older APK is still staged,
    // keep showing the older Install banner until the newer download verifies.
    // Never wipe the old file before the new one is ready — a failed ~70 MB
    // download used to leave phones stuck with a dead banner path.
    final staged = ready.value;
    if (staged != null &&
        compareVersions(manifest.version, staged.version) > 0) {
      debugPrint(
        '[update] newer ${manifest.version} available; keeping staged '
        '${staged.version} until download finishes',
      );
    }

    final alreadyStaged = target.existsSync() &&
        await _sha256Base64Url(target.path) == asset.hash;
    if (!alreadyStaged) {
      final part = File('${target.path}.part');
      if (part.existsSync()) {
        await part.delete();
      }
      debugPrint('[update] downloading ${manifest.version} from ${asset.url}');
      await _download(asset.url, part.path);
      if (await _sha256Base64Url(part.path) != asset.hash) {
        debugPrint('[update] download failed hash check — discarding');
        await part.delete();
        return;
      }
      // Swap only after hash OK. Keep the verified .part (and applied.json)
      // while clearing older staged APKs — wiping .part here would lose the
      // download we just finished.
      await _deleteStagedFiles(dir, keepPaths: {part.path});
      await part.rename(target.path);
    }

    await File('${dir.path}/$_stagedMetaName').writeAsString(
      jsonEncode({
        'id': manifest.id,
        'version': manifest.version,
        'file': target.path.split(Platform.pathSeparator).last,
        'sha256': asset.hash,
      }),
    );
    ready.value = ReadyUpdate(version: manifest.version, filePath: target.path);
    debugPrint('[update] ${manifest.version} staged');
  }

  Future<void> _download(String url, String path) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['user-agent'] = 'ALEX-Updater';
      // Full APK is ~70 MB; 60s was too short on many mobile networks and left
      // phones stuck on an older staged build forever.
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 10));
      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to download APK: HTTP ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }
      final sink = File(path).openWrite();
      try {
        // Bound the whole body transfer, not just the response headers.
        await response.stream.pipe(sink).timeout(const Duration(minutes: 10));
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  Future<UpdateManifest?> _fetchManifest(String currentVersion) async {
    final url = await getManifestUrl();
    if (url == null || url.isEmpty) return null;

    final response = await http
        .get(
          Uri.parse(url),
          headers: {
            'user-agent': 'ALEX-Updater',
            'alex-platform': 'android',
            'alex-current-version': currentVersion,
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to fetch manifest: HTTP ${response.statusCode}',
        uri: Uri.parse(url),
      );
    }
    return UpdateManifest.parse(response.body, platform: 'android');
  }

  Future<String> _currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    var v = info.version;
    if (!v.contains('+') && info.buildNumber.isNotEmpty) {
      v = '$v+${info.buildNumber}';
    }
    return v;
  }

  Future<Directory> _updatesDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/updates').create(recursive: true);
  }

  Future<bool> _recentlyApplied(Directory dir, String version) async {
    try {
      final f = File('${dir.path}/$_appliedMetaName');
      if (!f.existsSync()) return false;
      final meta = jsonDecode(await f.readAsString());
      if (meta is! Map<String, dynamic> || meta['version'] != version) {
        return false;
      }
      final at = DateTime.tryParse(meta['at'] as String? ?? '');
      return at != null && DateTime.now().difference(at) < _reapplyCooldown;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensureInstallPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.requestInstallPackages.status;
    if (status.isGranted) return true;
    final result = await Permission.requestInstallPackages.request();
    return result.isGranted;
  }

  Future<void> _deleteStagedFiles(
    Directory dir, {
    bool alsoApplied = false,
    Set<String> keepPaths = const {},
  }) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        if (keepPaths.contains(entity.path)) continue;
        if (!alsoApplied && entity.path.endsWith(_appliedMetaName)) {
          continue;
        }
        await entity.delete();
      }
    } catch (e) {
      debugPrint('[update] cleanup failed: $e');
    }
  }

  static Future<String> _sha256Base64Url(String path) =>
      compute(_hashFileSha256, path);

  @visibleForTesting
  static int compareVersions(String a, String b) {
    List<int> parse(String v) {
      final plus = v.indexOf('+');
      final core = plus == -1 ? v : v.substring(0, plus);
      final build = plus == -1 ? '' : v.substring(plus + 1);
      final parts = core
          .split('.')
          .map((s) => int.tryParse(s.trim()) ?? 0)
          .toList();
      while (parts.length < 3) {
        parts.add(0);
      }
      parts.add(int.tryParse(build) ?? 0);
      return parts;
    }

    final pa = parse(a);
    final pb = parse(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}

Future<String> _hashFileSha256(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}

class ReadyUpdate {
  const ReadyUpdate({required this.version, required this.filePath});

  final String version;
  final String filePath;
}

enum UpdateCheckStatus {
  unsupported,
  notConfigured,
  upToDate,
  updateReady,
  error,
}

@immutable
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    this.version,
    this.errorMessage,
  });

  final UpdateCheckStatus status;
  final String? version;
  final String? errorMessage;
}

class UpdateManifest {
  const UpdateManifest({
    required this.id,
    required this.version,
    required this.asset,
  });

  final String id;
  final String version;
  final UpdateAsset asset;

  static UpdateManifest? parse(String jsonText, {required String platform}) {
    try {
      final root = jsonDecode(jsonText);
      if (root is! Map<String, dynamic>) return null;
      final version = (root['version'] ?? root['runtimeVersion']) as String?;
      final platforms = root['platforms'];
      final entry = platforms is Map<String, dynamic> ? platforms[platform] : null;
      final launch = entry is Map<String, dynamic> ? entry['launchAsset'] : null;
      if (version == null || launch is! Map<String, dynamic>) return null;
      final url = launch['url'] as String?;
      final hash = launch['hash'] as String?;
      final key = launch['key'] as String?;
      if (url == null || url.isEmpty || hash == null || hash.isEmpty) {
        return null;
      }
      return UpdateManifest(
        id: root['id'] as String? ?? '',
        version: version,
        asset: UpdateAsset(
          url: url,
          hash: hash,
          key: (key == null || key.isEmpty) ? 'latest' : key,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

class UpdateAsset {
  const UpdateAsset({required this.url, required this.hash, required this.key});

  final String url;
  final String hash;
  final String key;
}
