import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sync_data.dart';
import 'sync_service.dart';

class WifiDirectSyncService {
  static const MethodChannel _methodChannel = MethodChannel('wifi_direct');
  static const EventChannel _eventChannel =
      EventChannel('wifi_direct_events');

  final SyncService _syncService = SyncService();
  StreamSubscription? _subscription;
  bool _started = false;
  bool _starting = false;
  bool _sending = false;
  Future<void> _importQueue = Future.value();

  String? _deviceId;
  String? _deviceName;

  final Map<String, DateTime> _peerSyncTimes = {};
  final Duration _peerSyncCooldown = const Duration(seconds: 20);

  Future<void> start({bool hostPreferred = false}) async {
    if (_started || _starting) {
      return;
    }
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    _starting = true;
    try {
      final permissionsOk = await _ensurePermissions();
      if (!permissionsOk) {
        debugPrint('WifiDirect: permissions not granted');
        return;
      }

      _deviceId ??= await _syncService.getDeviceId();
      _deviceName ??= await _getDeviceName();

      _subscription ??= _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (err) =>
            debugPrint('WifiDirect: event stream error: $err'),
      );

      await _methodChannel.invokeMethod('startWifiDirect', {
        'host': hostPreferred,
        'deviceId': _deviceId,
        'deviceName': _deviceName,
      });

      _started = true;
    } catch (e) {
      debugPrint('WifiDirect: failed to start: $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    if (!_started) {
      return;
    }
    try {
      await _methodChannel.invokeMethod('stopWifiDirect');
    } catch (e) {
      debugPrint('WifiDirect: failed to stop: $e');
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      _started = false;
    }
  }

  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }
    final sdkInt = await _getAndroidSdkInt();
    if (sdkInt != null && sdkInt >= 33) {
      final status = await Permission.nearbyWifiDevices.request();
      return status.isGranted;
    }
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<int?> _getAndroidSdkInt() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return null;
    }
  }

  Future<String> _getDeviceName() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.model ?? 'Android';
    } catch (_) {
      return 'Android';
    }
  }

  Future<void> _handleEvent(dynamic event) async {
    if (event is! Map) {
      return;
    }
    final data = Map<String, dynamic>.from(event);
    final type = data['type'];
    if (type == 'peer_connected') {
      await _handlePeerConnected(data);
    } else if (type == 'message') {
      await _handleMessage(data);
    }
  }

  Future<void> _handlePeerConnected(Map<String, dynamic> event) async {
    final peerId = event['peerId']?.toString();
    if (peerId != null) {
      final last = _peerSyncTimes[peerId];
      if (last != null &&
          DateTime.now().difference(last) < _peerSyncCooldown) {
        return;
      }
    }
    await _sendSyncData();
    if (peerId != null) {
      _peerSyncTimes[peerId] = DateTime.now();
    }
  }

  Future<void> _handleMessage(Map<String, dynamic> event) async {
    final payload = event['payload'];
    if (payload is! String || payload.isEmpty) {
      return;
    }

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      } else if (decoded is Map) {
        json = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      json = null;
    }

    if (json != null) {
      if (json['type'] == 'sync_data') {
        final fromId = json['fromId']?.toString();
        if (fromId != null && fromId == _deviceId) {
          return;
        }
        final data = json['data'];
        SyncData? syncData;
        if (data is Map) {
          syncData =
              SyncData.fromJson(Map<String, dynamic>.from(data));
        } else if (data is String) {
          syncData = _syncService.jsonToSyncData(data);
        }
        if (syncData != null) {
          await _queueImport(syncData);
        }
        return;
      }

      if (_looksLikeSyncData(json)) {
        final syncData = SyncData.fromJson(json);
        if (syncData.deviceId == _deviceId) {
          return;
        }
        await _queueImport(syncData);
        return;
      }
    }

    try {
      final syncData = _syncService.jsonToSyncData(payload);
      if (syncData.deviceId == _deviceId) {
        return;
      }
      await _queueImport(syncData);
    } catch (_) {
      return;
    }
  }

  bool _looksLikeSyncData(Map<String, dynamic> json) {
    return json.containsKey('products') &&
        json.containsKey('categories') &&
        json.containsKey('deviceId');
  }

  Future<void> _sendSyncData() async {
    if (_sending) {
      return;
    }
    _sending = true;
    try {
      final data = await _syncService.exportAllData();
      if (data.isEmpty) {
        return;
      }
      final payload = jsonEncode({
        'type': 'sync_data',
        'fromId': data.deviceId,
        'fromName': _deviceName ?? 'Android',
        'sentAt': DateTime.now().toIso8601String(),
        'data': data.toJson(),
      });
      await _methodChannel.invokeMethod('sendMessage', {
        'payload': payload,
      });
    } catch (e) {
      debugPrint('WifiDirect: failed to send sync data: $e');
    } finally {
      _sending = false;
    }
  }

  Future<void> _queueImport(SyncData data) async {
    if (data.isEmpty) {
      return;
    }
    _importQueue = _importQueue.then((_) async {
      try {
        await _syncService.importData(
          data,
          strategy: SyncStrategy.merge,
        );
      } catch (e) {
        debugPrint('WifiDirect: import failed: $e');
      }
    });
    return _importQueue;
  }
}
