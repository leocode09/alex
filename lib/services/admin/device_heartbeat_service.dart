import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../cloud/firebase_init.dart';
import '../cloud/firestore_paths.dart';
import '../cloud/shop_service.dart';
import 'install_id_service.dart';

/// Upserts `/devices/{installId}` so the super admin can enumerate every
/// install and see when it was last active.
///
/// - Writes on boot (best-effort; skipped if Firebase is unavailable).
/// - Rewrites `lastSeenAt` every [_interval] so "active in last 24h"
///   metrics stay fresh.
/// - Call [refreshShopMembership] after the device creates/joins/leaves
///   a shop so the admin can see the current tenant.
///
/// All writes are non-blocking and never throw from public API.
class DeviceHeartbeatService {
  DeviceHeartbeatService._internal();
  static final DeviceHeartbeatService _instance =
      DeviceHeartbeatService._internal();
  factory DeviceHeartbeatService() => _instance;

  static const Duration _interval = Duration(minutes: 5);
  static const String _deviceNamePrefKey = 'lan_device_name';
  static const String _firstSeenPrefKey = 'install_first_seen_iso';

  Timer? _timer;
  bool _started = false;
  String? _installId;
  String? _ownerUid;
  final ShopService _shopService = ShopService();

  /// Cached platform metadata (collected once per process).
  Map<String, dynamic>? _platformInfo;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    _installId = await InstallIdService.ensure();

    await _beatOnce(reason: 'boot');

    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      unawaited(_beatOnce(reason: 'interval'));
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  /// Call after `ShopService.createShop` / `joinShop` / `leaveShop` so
  /// the admin dashboard reflects the current tenant immediately.
  Future<void> refreshShopMembership() async {
    await _beatOnce(reason: 'shop_change');
  }

  Future<void> _beatOnce({required String reason}) async {
    if (!FirebaseInit.available) {
      return;
    }
    final id = _installId ?? await InstallIdService.ensure();
    _installId = id;

    try {
      final uid = _ownerUid ?? await _shopService.ensureAuth();
      if (uid == null) {
        return;
      }
      _ownerUid = uid;

      final prefs = await SharedPreferences.getInstance();
      final payload = await _buildPayload(
        prefs: prefs,
        uid: uid,
      );

      await FirebaseFirestore.instance
          .collection(FirestorePaths.devicesCollection)
          .doc(id)
          .set(payload, SetOptions(merge: true));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('DeviceHeartbeatService($reason) failed: $e\n$st');
      }
    }
  }

  Future<Map<String, dynamic>> _buildPayload({
    required SharedPreferences prefs,
    required String uid,
  }) async {
    final platform = await _resolvePlatformInfo();
    final firstSeenIso = prefs.getString(_firstSeenPrefKey);
    final firstSeen = firstSeenIso ?? DateTime.now().toIso8601String();
    if (firstSeenIso == null) {
      await prefs.setString(_firstSeenPrefKey, firstSeen);
    }

    return <String, dynamic>{
      'installId': _installId,
      'ownerUid': uid,
      'shopId': _shopService.cachedShopId,
      'shopCode': _shopService.cachedShopCode,
      'shopName': _shopService.cachedShopName,
      'deviceName': prefs.getString(_deviceNamePrefKey),
      'platform': platform['platform'],
      'osVersion': platform['osVersion'],
      'model': platform['model'],
      'appVersion': platform['appVersion'],
      'shorebirdPatch': await _resolveShorebirdPatch(),
      'firstSeenAt': firstSeen,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'lastSeenAtIso': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _resolvePlatformInfo() async {
    if (_platformInfo != null) {
      return _platformInfo!;
    }
    final info = <String, dynamic>{
      'platform': _platformName(),
      'osVersion': null,
      'model': null,
      'appVersion': _appVersion,
    };
    try {
      if (kIsWeb) {
        info['platform'] = 'web';
      } else if (Platform.isAndroid) {
        final a = await DeviceInfoPlugin().androidInfo;
        info['osVersion'] = 'Android ${a.version.release}';
        info['model'] = '${a.manufacturer} ${a.model}';
      } else if (Platform.isIOS) {
        final i = await DeviceInfoPlugin().iosInfo;
        info['osVersion'] = '${i.systemName} ${i.systemVersion}';
        info['model'] = i.utsname.machine;
      } else if (Platform.isWindows) {
        final w = await DeviceInfoPlugin().windowsInfo;
        info['osVersion'] = 'Windows ${w.productName}';
        info['model'] = w.computerName;
      } else if (Platform.isLinux) {
        final l = await DeviceInfoPlugin().linuxInfo;
        info['osVersion'] = l.prettyName;
        info['model'] = l.name;
      } else if (Platform.isMacOS) {
        final m = await DeviceInfoPlugin().macOsInfo;
        info['osVersion'] = 'macOS ${m.osRelease}';
        info['model'] = m.model;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DeviceHeartbeatService platform lookup failed: $e');
      }
    }
    _platformInfo = info;
    return info;
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
      if (Platform.isMacOS) return 'macos';
    } catch (_) {
      // swallow
    }
    return 'unknown';
  }

  Future<int?> _resolveShorebirdPatch() async {
    if (kIsWeb) {
      return null;
    }
    try {
      final updater = ShorebirdUpdater();
      if (!updater.isAvailable) {
        return null;
      }
      final patch = await updater.readCurrentPatch();
      return patch?.number;
    } catch (_) {
      return null;
    }
  }

  /// Pinned to the `version:` line in pubspec.yaml. Update here when
  /// bumping releases so admin dashboards show the right build.
  static const String _appVersion = '1.0.0+1';
}
