import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sync_data.dart';
import 'sync_message_utils.dart';
import 'sync_service.dart';

class WifiDirectSyncService extends ChangeNotifier {
  factory WifiDirectSyncService() => _instance;
  WifiDirectSyncService._internal();

  static final WifiDirectSyncService _instance =
      WifiDirectSyncService._internal();

  static const MethodChannel _methodChannel = MethodChannel('wifi_direct');
  static const EventChannel _eventChannel = EventChannel('wifi_direct_events');

  static const int _maxPayloadBytes = 1024 * 1024;
  static const Duration _healthCheckInterval = Duration(seconds: 12);
  static const Duration _peerDiscoveryInterval = Duration(seconds: 15);
  static const int _maxSyncRetryAttempts = 5;

  final SyncService _syncService = SyncService();
  final RecentMessageCache _messageCache =
      RecentMessageCache(ttl: const Duration(minutes: 3));

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
  Timer? _retryTimer;
  Timer? _healthTimer;
  Timer? _peerDiscoveryTimer;

  bool _pendingSync = false;
  DateTime? _lastSyncAt;
  DateTime? _lastPeerDiscoveryAt;
  int _retryAttempts = 0;

  bool get isRunning => _started;
  bool get isConnecting => _connecting;
  bool get isConnected => _isConnected;
  bool get isGroupOwner => _isGroupOwner;
  bool get hostPreferred => _hostPreferred;
  String get status => _status;
  String? get lastError => _lastError;
  List<WifiDirectPeer> get peers => List.unmodifiable(_peers);
  List<WifiDirectPeer> get connectedPeers => List.unmodifiable(_connectedPeers);
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
        onError: (err) {
          _lastError = 'Wi-Fi Direct event stream error: $err';
          _addLog(_lastError!);
          notifyListeners();
        },
      );

      await _methodChannel.invokeMethod('startWifiDirect', {
        'host': hostPreferred,
        'deviceId': _deviceId,
        'deviceName': _deviceName,
      });

      _started = true;
      _status = 'started';
      _lastError = null;
      _retryAttempts = 0;
      _startHealthTimer();
      _schedulePeerDiscovery(delay: const Duration(milliseconds: 300));
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
      _lastPeerDiscoveryAt = null;
      _syncDebounceTimer?.cancel();
      _syncDebounceTimer = null;
      _retryTimer?.cancel();
      _retryTimer = null;
      _healthTimer?.cancel();
      _healthTimer = null;
      _peerDiscoveryTimer?.cancel();
      _peerDiscoveryTimer = null;
      _sending = false;
      _retryAttempts = 0;
      _messageCache.clear();
      notifyListeners();
    }
  }

  Future<void> discoverPeers() async {
    if (!_started) {
      await start(hostPreferred: _hostPreferred);
    }
    try {
      await _methodChannel.invokeMethod('discoverPeers');
      _lastPeerDiscoveryAt = DateTime.now();
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
      _connecting = true;
      notifyListeners();
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
      final nearbyStatus = await Permission.nearbyWifiDevices.request();
      final locationStatus = await Permission.location.request();
      return nearbyStatus.isGranted && locationStatus.isGranted;
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
      return info.model;
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

    if (status == 'started' || status == 'server_listening') {
      _started = true;
    } else if (status == 'stopped') {
      _started = false;
      _isConnected = false;
      _connecting = false;
      _isGroupOwner = false;
      _connectedPeers = [];
    } else if (status == 'connecting') {
      _connecting = true;
    } else if (status == 'connected' || status == 'client_connected') {
      _connecting = false;
      _isConnected = true;
      _isGroupOwner = data['groupOwner'] == true;
      _retryAttempts = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
      unawaited(_flushPendingSync());
    } else if (status == 'disconnected') {
      _connecting = false;
      _isConnected = false;
      _isGroupOwner = false;
      _connectedPeers = [];
      _schedulePeerDiscovery();
    } else if (status == 'connect_failed' ||
        status == 'discover_failed' ||
        status == 'client_connect_failed' ||
        status == 'group_create_failed') {
      _connecting = false;
      final reason = data['reason']?.toString() ?? data['error']?.toString();
      _lastError = reason == null
          ? 'Wi-Fi Direct operation failed ($status).'
          : 'Wi-Fi Direct operation failed ($status): $reason';
      _schedulePeerDiscovery();
    } else if (status == 'p2p_enabled') {
      _schedulePeerDiscovery(delay: const Duration(milliseconds: 300));
    } else if (status == 'p2p_disabled') {
      _lastError = 'Wi-Fi Direct is disabled on this device.';
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
      _lastPeerDiscoveryAt = DateTime.now();
      notifyListeners();
    }
  }

  Future<void> _handlePeerConnected(Map<String, dynamic> event) async {
    final peerId = event['peerId']?.toString();
    final peerName = event['peerName']?.toString();
    if (peerId != null || peerName != null) {
      final exists = _connectedPeers.any(
        (peer) =>
            (peerId != null && peer.id == peerId) ||
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
      if (last != null && DateTime.now().difference(last) < _peerSyncCooldown) {
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

    if (SyncMessageUtils.utf8Size(payload) > _maxPayloadBytes) {
      _addLog('Dropped incoming payload that exceeded size limits.');
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

        final messageKey = SyncMessageUtils.buildMessageKey(
          messageId: json['messageId']?.toString(),
          payload: payload,
        );
        if (_messageCache.isDuplicate(messageKey)) {
          return;
        }

        final data = json['data'];
        SyncData? syncData;
        if (data is Map) {
          syncData = SyncData.fromJson(Map<String, dynamic>.from(data));
        } else if (data is String) {
          syncData = _syncService.jsonToSyncData(data);
        }

        if (syncData != null) {
          _messageCache.remember(messageKey);
          await _queueImport(syncData);
        }
        return;
      }

      if (_looksLikeSyncData(json)) {
        final messageKey = SyncMessageUtils.buildMessageKey(
          messageId: json['messageId']?.toString(),
          payload: payload,
        );
        if (_messageCache.isDuplicate(messageKey)) {
          return;
        }

        final syncData = SyncData.fromJson(json);
        if (syncData.deviceId == _deviceId) {
          return;
        }
        _messageCache.remember(messageKey);
        await _queueImport(syncData);
        return;
      }
    }

    try {
      final syncData = _syncService.jsonToSyncData(payload);
      if (syncData.deviceId == _deviceId) {
        return;
      }

      final messageKey = SyncMessageUtils.buildMessageKey(
        messageId: null,
        payload: payload,
      );
      if (_messageCache.isDuplicate(messageKey)) {
        return;
      }
      _messageCache.remember(messageKey);
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

  Future<bool> _sendSyncData() async {
    if (_sending || !_isConnected) {
      return false;
    }

    _sending = true;
    try {
      final data = await _syncService.exportAllData();
      if (data.isEmpty) {
        return true;
      }

      final messageId = SyncMessageUtils.nextMessageId(data.deviceId);
      final payload = jsonEncode({
        'type': 'sync_data',
        'messageId': messageId,
        'protocolVersion': 2,
        'fromId': data.deviceId,
        'fromName': _deviceName ?? 'Android',
        'sentAt': DateTime.now().toIso8601String(),
        'data': data.toJson(),
      });

      if (SyncMessageUtils.utf8Size(payload) > _maxPayloadBytes) {
        _lastError = 'Wi-Fi Direct payload exceeded 1 MB and was not sent.';
        notifyListeners();
        return false;
      }

      await _methodChannel.invokeMethod('sendMessage', {
        'payload': payload,
      });

      final key = SyncMessageUtils.buildMessageKey(
        messageId: messageId,
        payload: payload,
      );
      _messageCache.remember(key);
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('WifiDirect: failed to send sync data: $e');
      notifyListeners();
      return false;
    } finally {
      _sending = false;
    }
  }

  Future<void> _flushPendingSync() async {
    if (!_pendingSync) {
      return;
    }

    if (!_started || !_isConnected) {
      _scheduleSyncRetry(reason: 'not_connected');
      return;
    }

    if (_sending) {
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

    final sent = await _sendSyncData();
    if (sent) {
      _pendingSync = false;
      _lastSyncAt = DateTime.now();
      _retryAttempts = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }

    _scheduleSyncRetry(reason: 'send_failed');
  }

  void _scheduleSyncRetry({required String reason}) {
    if (!_pendingSync) {
      return;
    }

    if (_retryAttempts >= _maxSyncRetryAttempts) {
      _addLog(
          'Wi-Fi Direct retry paused after $_maxSyncRetryAttempts attempts.');
      _retryAttempts = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }

    _retryAttempts += 1;
    var seconds = 1 << (_retryAttempts - 1);
    if (seconds > 30) {
      seconds = 30;
    }

    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), _flushPendingSync);
    _addLog('Retrying Wi-Fi Direct sync in ${seconds}s ($reason).');
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

  void _startHealthTimer() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(_healthCheckInterval, (_) {
      _runHealthCheck();
    });
  }

  void _runHealthCheck() {
    if (!_started) {
      return;
    }

    final now = DateTime.now();
    _messageCache.prune(now);

    if (!_isConnected && !_connecting) {
      if (_lastPeerDiscoveryAt == null ||
          now.difference(_lastPeerDiscoveryAt!) > _peerDiscoveryInterval) {
        unawaited(discoverPeers());
      }
    }

    if (_pendingSync && _isConnected && !_sending && _retryTimer == null) {
      unawaited(_flushPendingSync());
    }
  }

  void _schedulePeerDiscovery({Duration delay = const Duration(seconds: 2)}) {
    if (!_started || _starting) {
      return;
    }

    _peerDiscoveryTimer?.cancel();
    _peerDiscoveryTimer = Timer(delay, () {
      unawaited(discoverPeers());
    });
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
