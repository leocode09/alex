import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/license_policy.dart';
import '../cloud/firebase_init.dart';
import '../cloud/firestore_paths.dart';
import '../cloud/shop_service.dart';
import 'install_id_service.dart';

/// Live-subscribes to the device and shop docs and produces a merged
/// [LicensePolicy] for the rest of the app.
///
/// The stream emits:
///   - [LicensePolicy.unrestricted] when Firebase is not available, the
///     device has not joined a shop yet, or any read error occurs.
///   - a merged policy whenever either the shop or device doc changes.
///
/// This service does not enforce the policy on its own — the [LicenseGate]
/// helper and route-level [LicenseWatcher] consume the stream and decide
/// what to do.
class LicenseService {
  LicenseService._internal();
  static final LicenseService _instance = LicenseService._internal();
  factory LicenseService() => _instance;

  final ShopService _shopService = ShopService();

  StreamController<LicensePolicy>? _controller;
  LicensePolicy _current = LicensePolicy.unrestricted;
  Map<String, dynamic>? _lastShopDoc;
  Map<String, dynamic>? _lastDeviceDoc;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _shopSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _deviceSub;

  String? _installId;
  String? _shopId;
  bool _attaching = false;
  Timer? _retryTimer;

  LicensePolicy get current => _current;

  Stream<LicensePolicy> watch() {
    _controller ??= StreamController<LicensePolicy>.broadcast(
      onListen: _kickstart,
      onCancel: _maybeDispose,
    );
    // Emit latest state on each new subscription so new listeners don't
    // wait for the next change.
    scheduleMicrotask(() {
      final c = _controller;
      if (c != null && !c.isClosed) {
        c.add(_current);
      }
    });
    return _controller!.stream;
  }

  void _kickstart() {
    unawaited(_reattach());
  }

  void _maybeDispose() {
    // Keep the subscriptions alive for the lifetime of the app; UI
    // widgets come and go but we always want the latest policy.
  }

  /// Call after shop membership changes (create/join/leave) so the
  /// listener reattaches to the new shop id.
  Future<void> refresh() async {
    await _reattach();
  }

  Future<void> _reattach() async {
    if (_attaching) return;
    _attaching = true;
    try {
      if (!FirebaseInit.available) {
        _emit(LicensePolicy.unrestricted);
        return;
      }

      _installId ??= await InstallIdService.ensure();
      await _shopService.loadCache();
      final newShopId = _shopService.cachedShopId;

      if (newShopId != _shopId) {
        await _shopSub?.cancel();
        _shopSub = null;
        _lastShopDoc = null;
        _shopId = newShopId;
      }

      if (_shopId != null && _shopId!.isNotEmpty && _shopSub == null) {
        _shopSub = FirebaseFirestore.instance
            .collection(FirestorePaths.shopsCollection)
            .doc(_shopId)
            .snapshots()
            .listen(
              (doc) {
                _lastShopDoc = doc.data();
                _emitMerged();
              },
              onError: (e) {
                if (kDebugMode) {
                  debugPrint('LicenseService shop listener error: $e');
                }
                _scheduleRetry();
              },
            );
      }

      if (_deviceSub == null && _installId != null) {
        _deviceSub = FirebaseFirestore.instance
            .collection(FirestorePaths.devicesCollection)
            .doc(_installId)
            .snapshots()
            .listen(
              (doc) {
                _lastDeviceDoc = doc.data();
                _emitMerged();
              },
              onError: (e) {
                if (kDebugMode) {
                  debugPrint('LicenseService device listener error: $e');
                }
                _scheduleRetry();
              },
            );
      }

      _emitMerged();
    } finally {
      _attaching = false;
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 30), () {
      unawaited(_reattach());
    });
  }

  void _emitMerged() {
    final merged = LicensePolicy.fromDocs(
      shop: _lastShopDoc,
      device: _lastDeviceDoc,
    );
    _emit(merged);
  }

  void _emit(LicensePolicy policy) {
    _current = policy;
    final c = _controller;
    if (c != null && !c.isClosed) {
      c.add(policy);
    }
  }
}
