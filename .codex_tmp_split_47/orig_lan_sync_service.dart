import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sync_data.dart';
import 'sync_message_utils.dart';
import 'sync_service.dart';

class LanSyncService extends ChangeNotifier {
  LanSyncService._internal();

  static final LanSyncService _instance = LanSyncService._internal();

  factory LanSyncService() => _instance;

  static const int discoveryPort = 42111;
  static const int tcpPort = 42112;
  static const Duration announceInterval = Duration(seconds: 2);
  static const Duration peerTimeout = Duration(seconds: 6);
  static const String _deviceNamePrefKey = 'lan_device_name';

  static const int _maxPayloadBytes = 1024 * 1024;
  static const Duration _healthCheckInterval = Duration(seconds: 10);
  static const Duration _handshakeTimeout = Duration(seconds: 6);
  static const Duration _connectionIdleTimeout = Duration(seconds: 35);
  static const Duration _pingInterval = Duration(seconds: 12);
  static const int _maxSyncRetryAttempts = 5;

  final SyncService _syncService = SyncService();
  final RecentMessageCache _messageCache =
      RecentMessageCache(ttl: const Duration(minutes: 3));

  bool _running = false;
  RawDatagramSocket? _discoverySocket;
  ServerSocket? _server;
  Timer? _announceTimer;
  Timer? _connectionHealthTimer;
  Timer? _retryTimer;

  final Map<String, LanPeer> _peers = <String, LanPeer>{};
  final Map<String, _LanConnection> _connections = <String, _LanConnection>{};
  final Set<String> _pendingConnections = <String>{};
  final Set<_LanConnection> _handshakingConnections = <_LanConnection>{};

  String _status = 'stopped';
  String? _lastError;

  final List<String> _logs = [];
  final List<LanSyncAction> _actions = [];
  List<String> _localAddresses = [];

  final Duration _syncDebounce = const Duration(milliseconds: 800);
  final Duration _minSyncInterval = const Duration(seconds: 3);
  Timer? _syncDebounceTimer;
  bool _pendingSync = false;
  DateTime? _lastSyncAt;
  bool _sending = false;
  int _retryAttempts = 0;

  Future<void> _importQueue = Future.value();

  String? _deviceId;
  String? _deviceName;

  bool get isRunning => _running;
  bool get isConnected => _connections.isNotEmpty;
  String get status => _status;
  String? get lastError => _lastError;
  String get deviceName =>
      (_deviceName != null && _deviceName!.trim().isNotEmpty)
          ? _deviceName!.trim()
          : 'Device';
  String get deviceId => (_deviceId != null && _deviceId!.trim().isNotEmpty)
      ? _deviceId!
      : 'unknown_device';
  List<String> get localAddresses => List.unmodifiable(_localAddresses);
  List<String> get logs => List.unmodifiable(_logs);
  List<LanSyncAction> get actions => List.unmodifiable(_actions);
  List<LanPeer> get peers =>
      List.unmodifiable(_peers.values.toList()..sort(_peerSort));
  Set<String> get connectedPeerIds => Set.unmodifiable(_connections.keys);
  List<String> get connectedPeers =>
      _connections.values.map((connection) => connection.displayName).toList();

  Future<void> initialize() async {
    if (kIsWeb) {
      if (_deviceName == null || _deviceName!.trim().isEmpty) {
        _deviceName = 'Device';
      }
      return;
    }
    await _ensureDeviceInfo();
    notifyListeners();
  }

  Future<void> setDeviceName(String value) async {
    final nextValue = value.trim();
    final prefs = await SharedPreferences.getInstance();
    final resolvedName =
        nextValue.isEmpty ? await _getDefaultDeviceName() : nextValue;

    if (nextValue.isEmpty) {
      await prefs.remove(_deviceNamePrefKey);
    } else {
      await prefs.setString(_deviceNamePrefKey, nextValue);
    }

    _deviceName = resolvedName;
    _addLog('Device name set to "$resolvedName".');
    if (_running) {
      _sendLanAnnounce();
    }
    notifyListeners();
  }

  Future<void> start() async {
    if (kIsWeb) {
      return;
    }
    if (_running) {
      return;
    }
    _lastError = null;
    await _ensureDeviceInfo();
    try {
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        tcpPort,
        shared: true,
      );
      _server!.listen(
        (socket) => _handleLanSocket(socket, outbound: false),
        onError: (error) => _addLog('LAN server error: $error'),
      );

      _discoverySocket = await _openDiscoverySocket();
      _discoverySocket!.broadcastEnabled = true;
      _discoverySocket!.listen(
        _handleLanDatagram,
        onError: (error) => _addLog('LAN discovery error: $error'),
      );

      _announceTimer?.cancel();
      _announceTimer = Timer.periodic(
        announceInterval,
        (_) => _sendLanAnnounce(),
      );

      _connectionHealthTimer?.cancel();
      _connectionHealthTimer = Timer.periodic(
        _healthCheckInterval,
        (_) => _runConnectionHealthCheck(),
      );

      _running = true;
      _status = 'running';
      _retryAttempts = 0;
      _sendLanAnnounce();
      await refreshLocalAddresses();
      notifyListeners();
      _addLog(
        'LAN discovery running on UDP $discoveryPort / TCP $tcpPort.',
      );
    } catch (e) {
      _addLog('LAN start failed: $e');
      _lastError = e.toString();
      await stop();
    }
  }

  Future<void> stop() async {
    _announceTimer?.cancel();
    _announceTimer = null;

    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;

    _retryTimer?.cancel();
    _retryTimer = null;

    _discoverySocket?.close();
    _discoverySocket = null;

    final server = _server;
    _server = null;
    if (server != null) {
      await server.close();
    }

    final connections = _connections.values.toSet().toList();
    _connections.clear();
    for (final connection in connections) {
      await connection.close();
    }

    final handshakes = _handshakingConnections.toList();
    _handshakingConnections.clear();
    for (final connection in handshakes) {
      await connection.close();
    }

    _pendingConnections.clear();
    _peers.clear();

    _running = false;
    _status = 'stopped';
    _pendingSync = false;
    _lastSyncAt = null;
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = null;
    _sending = false;
    _retryAttempts = 0;
    _messageCache.clear();
    notifyListeners();
  }

  Future<void> refreshLocalAddresses() async {
    if (kIsWeb) {
      return;
    }
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final addresses = <String>{};
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) {
            addresses.add(address.address);
          }
        }
      }
      _localAddresses = addresses.toList()..sort();
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      _addLog('Failed to read IPs: $e');
      notifyListeners();
    }
  }

  Future<void> connectToHost(
    String host, {
    int port = tcpPort,
  }) async {
    if (kIsWeb) {
      return;
    }
    if (host.trim().isEmpty) {
      return;
    }
    await _ensureDeviceInfo();
    try {
      if (!_running) {
        await start();
      }
      final socket = await Socket.connect(
        host.trim(),
        port,
        timeout: const Duration(seconds: 3),
      );
      _handleLanSocket(socket, outbound: true);
    } catch (e) {
      _lastError = e.toString();
      _addLog('LAN connect failed to $host:$port: $e');
      notifyListeners();
    }
  }

  Future<void> triggerSync({String reason = 'update'}) async {
    if (kIsWeb) {
      return;
    }
    if (kDebugMode) {
      debugPrint('LanSync: trigger sync ($reason)');
    }
    if (!_running) {
      await start();
    }
    _addLog('Sync requested (${_formatReason(reason)}).');
    _pendingSync = true;
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(_syncDebounce, _flushPendingSync);
  }

  void _handleLanDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) {
      return;
    }

    final socket = _discoverySocket;
    if (socket == null) {
      return;
    }

    Datagram? datagram;
    while ((datagram = socket.receive()) != null) {
      final message = utf8.decode(datagram!.data, allowMalformed: true);
      try {
        final data = jsonDecode(message);
        if (data is! Map<String, dynamic>) {
          continue;
        }
        if (data['type'] != 'lan_announce') {
          continue;
        }

        final peerId = data['id'];
        if (peerId is! String || peerId == _deviceId) {
          continue;
        }

        final peerName =
            data['name'] is String ? data['name'] as String : peerId;
        final port = data['port'] is int ? data['port'] as int : tcpPort;
        final now = DateTime.now();
        final peer = LanPeer(
          id: peerId,
          name: peerName,
          address: datagram.address,
          port: port,
          lastSeen: now,
        );

        final existing = _peers[peerId];
        _peers[peerId] = peer;

        final changed = existing == null ||
            existing.name != peer.name ||
            existing.address.address != peer.address.address ||
            existing.port != peer.port;
        if (changed) {
          notifyListeners();
        }

        _maybeConnectToLanPeer(peer);
      } catch (_) {
        // Ignore malformed LAN discovery packets.
      }
    }
  }

  void _sendLanAnnounce() {
    final socket = _discoverySocket;
    if (socket == null) {
      return;
    }

    final data = <String, dynamic>{
      'type': 'lan_announce',
      'id': _deviceId,
      'name': _deviceName,
      'port': tcpPort,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'protocolVersion': 2,
    };
    final bytes = utf8.encode(jsonEncode(data));
    try {
      socket.send(bytes, InternetAddress('255.255.255.255'), discoveryPort);
    } catch (e) {
      _addLog('LAN announce failed: $e');
    }

    _pruneLanPeers();
  }

  void _pruneLanPeers() {
    if (_peers.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final stalePeers = _peers.entries
        .where((entry) => now.difference(entry.value.lastSeen) > peerTimeout)
        .map((entry) => entry.key)
        .toList();

    if (stalePeers.isEmpty) {
      return;
    }

    for (final peerId in stalePeers) {
      _peers.remove(peerId);
    }
    notifyListeners();
  }

  void _maybeConnectToLanPeer(LanPeer peer) {
    if (_connections.containsKey(peer.id) ||
        _pendingConnections.contains(peer.id)) {
      return;
    }

    if (!_shouldInitiateLanConnection(peer.id)) {
      return;
    }

    _pendingConnections.add(peer.id);
    unawaited(_connectToLanPeer(peer));
  }

  bool _shouldInitiateLanConnection(String peerId) {
    final id = _deviceId;
    if (id == null) {
      return false;
    }
    return id.compareTo(peerId) < 0;
  }

  Future<void> _connectToLanPeer(LanPeer peer) async {
    try {
      final socket = await Socket.connect(
        peer.address,
        peer.port,
        timeout: const Duration(seconds: 3),
      );
      _handleLanSocket(socket, outbound: true);
    } catch (error) {
      _addLog(
        'LAN connect failed to ${peer.name} (${peer.address.address}:${peer.port}): $error',
      );
    } finally {
      _pendingConnections.remove(peer.id);
    }
  }

  void _handleLanSocket(Socket socket, {required bool outbound}) {
    socket.setOption(SocketOption.tcpNoDelay, true);
    final connection = _LanConnection(socket: socket, outbound: outbound);
    _handshakingConnections.add(connection);
    connection.subscription = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => _onLanLine(connection, line),
          onError: (error) => _removeLanConnection(connection, error: error),
          onDone: () => _removeLanConnection(connection),
          cancelOnError: true,
        );

    _sendLanHello(connection);
  }

  void _sendLanHello(_LanConnection connection) {
    final data = <String, dynamic>{
      'type': 'lan_hello',
      'id': _deviceId,
      'name': _deviceName,
      'protocolVersion': 2,
    };
    connection.sendJson(jsonEncode(data));
  }

  void _onLanLine(_LanConnection connection, String line) {
    connection.touch();
    try {
      final data = jsonDecode(line);
      if (data is! Map<String, dynamic>) {
        return;
      }

      final type = data['type'];
      if (type == 'lan_hello') {
        final peerId = data['id'];
        final peerName = data['name'];
        if (peerId is String) {
          _registerLanConnection(
            connection,
            peerId: peerId,
            peerName: peerName is String ? peerName : peerId,
          );
        }
        return;
      }

      if (type == 'lan_ping') {
        connection.sendJson(
          jsonEncode({
            'type': 'lan_pong',
            'id': _deviceId,
            'name': _deviceName,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }),
        );
        return;
      }

      if (type == 'lan_pong') {
        return;
      }

      if (connection.peerId != null) {
        unawaited(
          _handleIncomingPayload(
            line,
            fallbackSourceId: connection.peerId,
            fallbackSourceName: connection.peerName,
          ),
        );
      }
    } catch (_) {
      if (connection.peerId != null) {
        unawaited(
          _handleIncomingPayload(
            line,
            fallbackSourceId: connection.peerId,
            fallbackSourceName: connection.peerName,
          ),
        );
      }
    }
  }

  void _registerLanConnection(
    _LanConnection connection, {
    required String peerId,
    required String peerName,
  }) {
    if (peerId == _deviceId) {
      _handshakingConnections.remove(connection);
      unawaited(connection.close());
      return;
    }

    final existing = _connections[peerId];
    if (existing != null && existing != connection) {
      final preferOutbound = _shouldInitiateLanConnection(peerId);
      final keepNew =
          preferOutbound ? connection.outbound : !connection.outbound;
      if (!keepNew) {
        _handshakingConnections.remove(connection);
        unawaited(connection.close());
        return;
      }
      unawaited(existing.close());
    }

    connection.peerId = peerId;
    connection.peerName = peerName;
    connection.markHandshakeComplete();
    _handshakingConnections.remove(connection);
    _connections[peerId] = connection;
    _pendingConnections.remove(peerId);

    final remoteAddress = connection.socket.remoteAddress;
    final existingPeer = _peers[peerId];
    _peers[peerId] = LanPeer(
      id: peerId,
      name: peerName,
      address: remoteAddress,
      port: connection.socket.remotePort,
      lastSeen: DateTime.now(),
    );

    _addLog(
      'LAN connected.',
      deviceId: peerId,
      deviceName: peerName,
    );
    if (existingPeer == null) {
      notifyListeners();
    } else {
      notifyListeners();
    }

    unawaited(triggerSync(reason: 'lan_connected'));
  }

  void _removeLanConnection(_LanConnection connection, {Object? error}) {
    final peerId = connection.peerId;
    _handshakingConnections.remove(connection);

    if (peerId != null && _connections[peerId] == connection) {
      _connections.remove(peerId);
      final name = connection.peerName ?? peerId;
      _addLog(
        'LAN disconnected.',
        deviceId: peerId,
        deviceName: name,
      );
    }

    if (error != null) {
      _addLog('LAN socket error: $error');
    }

    notifyListeners();
    unawaited(connection.close());
  }

  Future<void> _handleIncomingPayload(
    String payload, {
    String? fallbackSourceId,
    String? fallbackSourceName,
  }) async {
    if (payload.isEmpty ||
        SyncMessageUtils.utf8Size(payload) > _maxPayloadBytes) {
      _addLog('Dropped payload that exceeded size limits.');
      return;
    }

    await _ensureDeviceInfo();
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
        final fromId = json['fromId']?.toString() ?? fallbackSourceId;
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

        final sourceName = _resolveSourceDeviceName(
          deviceId: fromId,
          providedName: json['fromName']?.toString() ?? fallbackSourceName,
        );
        final data = json['data'];
        SyncData? syncData;
        if (data is Map) {
          syncData = SyncData.fromJson(Map<String, dynamic>.from(data));
        } else if (data is String) {
          syncData = _syncService.jsonToSyncData(data);
        }
        if (syncData != null) {
          _messageCache.remember(messageKey);
          _addLog(
            'Received sync data (${syncData.totalItems} items).',
            deviceId: fromId,
            deviceName: sourceName,
          );
          await _queueImport(
            syncData,
            sourceDeviceId: fromId,
            sourceDeviceName: sourceName,
          );
        }
        return;
      }

      if (_looksLikeSyncData(json)) {
        final syncData = SyncData.fromJson(json);
        if (syncData.deviceId == _deviceId) {
          return;
        }

        final messageKey = SyncMessageUtils.buildMessageKey(
          messageId: json['messageId']?.toString(),
          payload: payload,
        );
        if (_messageCache.isDuplicate(messageKey)) {
          return;
        }
        _messageCache.remember(messageKey);

        final sourceName = _resolveSourceDeviceName(
          deviceId: syncData.deviceId,
          providedName: fallbackSourceName,
        );
        _addLog(
          'Received sync data (${syncData.totalItems} items).',
          deviceId: syncData.deviceId,
          deviceName: sourceName,
        );
        await _queueImport(
          syncData,
          sourceDeviceId: syncData.deviceId,
          sourceDeviceName: sourceName,
        );
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

      final sourceName = _resolveSourceDeviceName(
        deviceId: syncData.deviceId,
        providedName: fallbackSourceName,
      );
      _addLog(
        'Received sync data (${syncData.totalItems} items).',
        deviceId: syncData.deviceId,
        deviceName: sourceName,
      );
      await _queueImport(
        syncData,
        sourceDeviceId: syncData.deviceId,
        sourceDeviceName: sourceName,
      );
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
    if (_sending) {
      return false;
    }
    if (_connections.isEmpty) {
      return false;
    }

    _sending = true;
    try {
      await _ensureDeviceInfo();
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
        'fromName': _deviceName ?? 'Device',
        'sentAt': DateTime.now().toIso8601String(),
        'data': data.toJson(),
      });

      if (SyncMessageUtils.utf8Size(payload) > _maxPayloadBytes) {
        _lastError = 'Sync payload exceeded 1 MB and was not sent.';
        _addLog(_lastError!);
        notifyListeners();
        return false;
      }

      final delivered = _sendPayload(payload);
      if (delivered == 0) {
        _addLog('No active peers were available to receive sync payload.');
        return false;
      }

      final key = SyncMessageUtils.buildMessageKey(
        messageId: messageId,
        payload: payload,
      );
      _messageCache.remember(key);
      _addLog(
        'Shared sync data (${data.totalItems} items) to $delivered peer(s).',
      );
      return true;
    } catch (e) {
      _lastError = e.toString();
      _addLog('Send failed: $e');
      notifyListeners();
      return false;
    } finally {
      _sending = false;
    }
  }

  int _sendPayload(String payload) {
    if (payload.isEmpty) {
      return 0;
    }

    var delivered = 0;
    final snapshot = _connections.values.toList();
    for (final connection in snapshot) {
      final sent = connection.sendJson(payload);
      if (sent) {
        delivered++;
      } else {
        _removeLanConnection(
          connection,
          error: 'Failed to send sync payload.',
        );
      }
    }
    return delivered;
  }

  Future<void> _flushPendingSync() async {
    if (!_pendingSync) {
      return;
    }

    if (!isConnected) {
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
      _addLog('Sync retry paused after $_maxSyncRetryAttempts attempts.');
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
    _addLog('Retrying sync in ${seconds}s (${_formatReason(reason)}).');
  }

  Future<void> _queueImport(
    SyncData data, {
    String? sourceDeviceId,
    String? sourceDeviceName,
  }) async {
    if (data.isEmpty) {
      return;
    }
    _importQueue = _importQueue.then((_) async {
      try {
        final result = await _syncService.importData(
          data,
          strategy: SyncStrategy.merge,
        );
        if (result.success) {
          _addLog(
            'Applied sync data (${result.totalImported} imported).',
            deviceId: sourceDeviceId ?? data.deviceId,
            deviceName: sourceDeviceName,
          );
        } else {
          _addLog(
            'Import failed: ${result.message}',
            deviceId: sourceDeviceId ?? data.deviceId,
            deviceName: sourceDeviceName,
          );
        }
      } catch (e) {
        _addLog(
          'Import failed: $e',
          deviceId: sourceDeviceId ?? data.deviceId,
          deviceName: sourceDeviceName,
        );
      }
    });
    return _importQueue;
  }

  void _runConnectionHealthCheck() {
    if (!_running) {
      return;
    }

    final now = DateTime.now();
    _messageCache.prune(now);
    _pruneLanPeers();

    final allConnections = <_LanConnection>{
      ..._handshakingConnections,
      ..._connections.values,
    };

    for (final connection in allConnections) {
      if (connection.isClosed) {
        continue;
      }

      final connectedFor = now.difference(connection.connectedAt);
      if (!connection.handshakeComplete && connectedFor > _handshakeTimeout) {
        _removeLanConnection(connection, error: 'LAN handshake timed out.');
        continue;
      }

      final idleFor = now.difference(connection.lastSeenAt);
      if (idleFor > _connectionIdleTimeout) {
        _removeLanConnection(connection, error: 'LAN connection became idle.');
        continue;
      }

      if (connection.handshakeComplete &&
          now.difference(connection.lastPingAt) >= _pingInterval) {
        connection.sendPing(_deviceId, _deviceName);
      }
    }

    if (_pendingSync && isConnected && !_sending && _retryTimer == null) {
      unawaited(_flushPendingSync());
    }
  }

  Future<RawDatagramSocket> _openDiscoverySocket() async {
    try {
      return await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
    } catch (_) {
      return RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
      );
    }
  }

  Future<void> _ensureDeviceInfo() async {
    _deviceId ??= await _syncService.getDeviceId();
    _deviceName ??=
        await _getPreferredDeviceName() ?? await _getDefaultDeviceName();
  }

  Future<String?> _getPreferredDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString(_deviceNamePrefKey)?.trim();
    if (savedName == null || savedName.isEmpty) {
      return null;
    }
    return savedName;
  }

  Future<String> _getDefaultDeviceName() async {
    if (!Platform.isAndroid) {
      final hostname = Platform.localHostname;
      return hostname.isNotEmpty ? hostname : 'Device';
    }
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.model;
    } catch (_) {
      return 'Android';
    }
  }

  String _resolveSourceDeviceName({
    required String? deviceId,
    String? providedName,
  }) {
    final name = providedName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    if (deviceId != null) {
      final connectionName = _connections[deviceId]?.peerName?.trim();
      if (connectionName != null && connectionName.isNotEmpty) {
        return connectionName;
      }
      final peerName = _peers[deviceId]?.name.trim();
      if (peerName != null && peerName.isNotEmpty) {
        return peerName;
      }
      if (deviceId == _deviceId) {
        return deviceName;
      }
      return deviceId;
    }
    return 'Unknown device';
  }

  String _formatReason(String reason) {
    final value = reason.trim();
    if (value.isEmpty) {
      return 'update';
    }
    return value.replaceAll('_', ' ');
  }

  void _addLog(
    String message, {
    String? deviceId,
    String? deviceName,
  }) {
    const maxLogs = 50;
    const maxActions = 300;
    final normalizedDeviceId = (deviceId != null && deviceId.trim().isNotEmpty)
        ? deviceId.trim()
        : this.deviceId;
    final normalizedDeviceName = _resolveSourceDeviceName(
      deviceId: normalizedDeviceId,
      providedName: deviceName,
    );
    final action = LanSyncAction(
      timestamp: DateTime.now(),
      message: message,
      deviceId: normalizedDeviceId,
      deviceName: normalizedDeviceName,
    );

    _actions.add(action);
    if (_actions.length > maxActions) {
      _actions.removeAt(0);
    }

    _logs.add('[${action.deviceName}] ${action.message}');
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
    notifyListeners();
  }

  static int _peerSort(LanPeer a, LanPeer b) {
    final name = a.name.compareTo(b.name);
    if (name != 0) {
      return name;
    }
    return a.id.compareTo(b.id);
  }
}

@immutable
class LanSyncAction {
  const LanSyncAction({
    required this.timestamp,
    required this.message,
    required this.deviceId,
    required this.deviceName,
  });

  final DateTime timestamp;
  final String message;
  final String deviceId;
  final String deviceName;
}

@immutable
class LanPeer {
  const LanPeer({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.lastSeen,
  });

  final String id;
  final String name;
  final InternetAddress address;
  final int port;
  final DateTime lastSeen;

  String get label => '$name (${address.address}:$port)';
}

class _LanConnection {
  _LanConnection({required this.socket, required this.outbound})
      : connectedAt = DateTime.now(),
        lastSeenAt = DateTime.now(),
        lastPingAt = DateTime.fromMillisecondsSinceEpoch(0);

  final Socket socket;
  final bool outbound;
  final DateTime connectedAt;

  String? peerId;
  String? peerName;
  StreamSubscription<String>? subscription;

  bool handshakeComplete = false;
  DateTime lastSeenAt;
  DateTime lastPingAt;
  bool _closed = false;

  String get displayName =>
      peerName ??
      peerId ??
      '${socket.remoteAddress.address}:${socket.remotePort}';

  bool get isClosed => _closed;

  void markHandshakeComplete() {
    handshakeComplete = true;
    touch();
  }

  void touch() {
    lastSeenAt = DateTime.now();
  }

  bool sendJson(String jsonMessage) {
    if (_closed) {
      return false;
    }
    try {
      socket.add(utf8.encode(jsonMessage));
      socket.add(const [10]);
      return true;
    } catch (_) {
      return false;
    }
  }

  void sendPing(String? deviceId, String? deviceName) {
    if (_closed) {
      return;
    }
    lastPingAt = DateTime.now();
    sendJson(
      jsonEncode({
        'type': 'lan_ping',
        'id': deviceId,
        'name': deviceName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await subscription?.cancel();
    socket.destroy();
  }
}
