import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sync_data.dart';
import 'sync_service.dart';

class WifiDirectSyncService extends ChangeNotifier {
  factory WifiDirectSyncService() => _instance;
  WifiDirectSyncService._internal();

  static final WifiDirectSyncService _instance =
      WifiDirectSyncService._internal();

  static const MethodChannel _methodChannel = MethodChannel('wifi_direct');
  static const EventChannel _eventChannel =
      EventChannel('wifi_direct_events');

  final SyncService _syncService = SyncService();
  StreamSubscription? _subscription;
  bool _started = false;
  bool _starting = false;
  bool _sending = false;
  bool _connecting = false;
  bool _isConnected = false;
  bool _isGroupOwner = false;
  String _status = 'stopped';
  String? _lastError;
  bool _hostPreferred = false;

  List<WifiDirectPeer> _peers = [];
  List<WifiDirectPeer> _connectedPeers = [];
  final List<String> _logs = [];

  Future<void> _importQueue = Future.value();

  String? _deviceId;
  String? _deviceName;

  final Map<String, DateTime> _peerSyncTimes = {};
  final Duration _peerSyncCooldown = const Duration(seconds: 20);
  final Duration _syncDebounce = const Duration(milliseconds: 800);
  final Duration _minSyncInterval = const Duration(seconds: 3);
  Timer? _syncDebounceTimer;
  bool _pendingSync = false;
  DateTime? _lastSyncAt;

  bool get isRunning => _started;
  bool get isConnecting => _connecting;
  bool get isConnected => _isConnected;
  bool get isGroupOwner => _isGroupOwner;
  bool get hostPreferred => _hostPreferred;
  String get status => _status;
  String? get lastError => _lastError;
  List<WifiDirectPeer> get peers => List.unmodifiable(_peers);
  List<WifiDirectPeer> get connectedPeers =>
      List.unmodifiable(_connectedPeers);
  List<String> get logs => List.unmodifiable(_logs);

  Future<void> start({bool hostPreferred = false}) async {
    if (_starting) {
      return;
    }
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    if (_started && _hostPreferred != hostPreferred) {
      await stop();
    } else if (_started) {
      return;
    }
    _hostPreferred = hostPreferred;
    _starting = true;
    try {
      final permissionsOk = await _ensurePermissions();
      if (!permissionsOk) {
        _lastError = 'Permissions not granted';
        debugPrint('WifiDirect: permissions not granted');
        notifyListeners();
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
      _status = 'started';
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('WifiDirect: failed to start: $e');
      notifyListeners();
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
      _connecting = false;
      _isConnected = false;
      _isGroupOwner = false;
      _status = 'stopped';
      _peers = [];
      _connectedPeers = [];
      _pendingSync = false;
      _lastSyncAt = null;
      _syncDebounceTimer?.cancel();
      _syncDebounceTimer = null;
      notifyListeners();
    }
  }

  Future<void> discoverPeers() async {
    if (!_started) {
      await start(hostPreferred: _hostPreferred);
    }
    try {
      await _methodChannel.invokeMethod('discoverPeers');
    } catch (e) {
      _lastError = e.toString();
      debugPrint('WifiDirect: discover peers failed: $e');
      notifyListeners();
    }
  }

  Future<void> connectToPeer(String address) async {
    if (address.isEmpty) {
      return;
    }
    if (!_started) {
      await start(hostPreferred: _hostPreferred);
    }
    try {
      await _methodChannel.invokeMethod('connectToPeer', {
        'deviceAddress': address,
      });
    } catch (e) {
      _lastError = e.toString();
      debugPrint('WifiDirect: connect failed: $e');
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (!_started) {
      return;
    }
    try {
      await _methodChannel.invokeMethod('disconnect');
    } catch (e) {
      _lastError = e.toString();
      debugPrint('WifiDirect: disconnect failed: $e');
      notifyListeners();
    }
  }

  Future<void> setHostPreferred(bool value) async {
    if (_hostPreferred == value) {
      return;
    }
    _hostPreferred = value;
    notifyListeners();
    await start(hostPreferred: value);
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
    if (type == 'status') {
      _handleStatus(data);
    } else if (type == 'peers') {
      _handlePeers(data);
    } else if (type == 'peer_connected') {
      await _handlePeerConnected(data);
    } else if (type == 'message') {
      await _handleMessage(data);
    } else if (type == 'log') {
      final message = data['message']?.toString();
      if (message != null) {
        _addLog(message);
      }
    }
  }

  void _handleStatus(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? 'unknown';
    _status = status;
    if (status == 'started') {
      _started = true;
    } else if (status == 'stopped') {
      _started = false;
      _isConnected = false;
      _connecting = false;
      _isGroupOwner = false;
      _connectedPeers = [];
    } else if (status == 'connecting') {
      _connecting = true;
    } else if (status == 'connected') {
      _connecting = false;
      _isConnected = true;
      _isGroupOwner = data['groupOwner'] == true;
      _flushPendingSync();
    } else if (status == 'disconnected') {
      _connecting = false;
      _isConnected = false;
      _isGroupOwner = false;
      _connectedPeers = [];
    }
    notifyListeners();
  }

  Future<void> triggerSync({String reason = 'update'}) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    if (kDebugMode) {
      debugPrint('WifiDirect: trigger sync ($reason)');
    }
    _pendingSync = true;
    if (!_started && !_starting) {
      await start(hostPreferred: _hostPreferred);
    }
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(_syncDebounce, _flushPendingSync);
  }

  void _handlePeers(Map<String, dynamic> data) {
    final rawPeers = data['peers'];
    if (rawPeers is List) {
      _peers = rawPeers.map((peer) {
        if (peer is Map) {
          final map = Map<String, dynamic>.from(peer);
          return WifiDirectPeer(
            name: map['name']?.toString(),
            address: map['address']?.toString(),
            status: map['status']?.toString(),
          );
        }
        return const WifiDirectPeer();
      }).toList();
      notifyListeners();
    }
  }

  Future<void> _handlePeerConnected(Map<String, dynamic> event) async {
    final peerId = event['peerId']?.toString();
    final peerName = event['peerName']?.toString();
    if (peerId != null || peerName != null) {
      final exists = _connectedPeers.any(
        (peer) => (peerId != null && peer.id == peerId) ||
            (peerName != null && peer.name == peerName),
      );
      if (!exists) {
        _connectedPeers = [
          ..._connectedPeers,
          WifiDirectPeer(id: peerId, name: peerName),
        ];
        notifyListeners();
      }
    }
    if (peerId != null) {
      final last = _peerSyncTimes[peerId];
      if (last != null &&
          DateTime.now().difference(last) < _peerSyncCooldown) {
        return;
      }
    }
    await triggerSync(reason: 'peer_connected');
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
      _lastError = e.toString();
      debugPrint('WifiDirect: failed to send sync data: $e');
      notifyListeners();
    } finally {
      _sending = false;
    }
  }

  Future<void> _flushPendingSync() async {
    if (!_pendingSync) {
      return;
    }
    if (!_started || !_isConnected || _sending) {
      return;
    }
    final now = DateTime.now();
    if (_lastSyncAt != null) {
      final elapsed = now.difference(_lastSyncAt!);
      if (elapsed < _minSyncInterval) {
        _syncDebounceTimer?.cancel();
        _syncDebounceTimer =
            Timer(_minSyncInterval - elapsed, _flushPendingSync);
        return;
      }
    }
    _pendingSync = false;
    await _sendSyncData();
    _lastSyncAt = DateTime.now();
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

  void _addLog(String message) {
    const maxLogs = 50;
    _logs.add(message);
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
    notifyListeners();
  }
}

@immutable
class WifiDirectPeer {
  final String? id;
  final String? name;
  final String? address;
  final String? status;

  const WifiDirectPeer({
    this.id,
    this.name,
    this.address,
    this.status,
  });

  String get displayName =>
      (name != null && name!.isNotEmpty) ? name! : (id ?? address ?? 'Unknown');
}
