import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../helpers/license_gate.dart';
import '../models/account_state.dart';
import '../models/license_policy.dart';
import '../models/sync_data.dart';
import 'admin/device_registration_service.dart';
import 'cloud/account_service.dart';
import 'cloud/firebase_init.dart';
import 'cloud/shop_service.dart';
import 'identity_label.dart';
import 'shop_peer_gate.dart';
import 'sync_frame_codec.dart';
import 'sync_message_utils.dart';
import 'sync_service.dart';

class LanSyncService extends ChangeNotifier {
  LanSyncService._internal();

  static final LanSyncService _instance = LanSyncService._internal();

  factory LanSyncService() => _instance;

  static const int discoveryPort = 42111;
  static const int tcpPort = 42112;
  static const int protocolVersion = 3;
  static const Duration announceInterval = Duration(seconds: 2);
  static const Duration peerTimeout = Duration(seconds: 6);
  static const int _maxPayloadBytes = SyncMessageUtils.maxFramePayloadBytes;
  static const int _maxSyncPayloadBytes =
      SyncMessageUtils.maxAssembledPayloadBytes;
  // Frames longer than this are parsed in a background isolate; parsing a
  // multi-megabyte sync payload on the UI isolate freezes the app. Chunk
  // envelopes are exempt (see _looksLikeChunkFrame) — they are bounded to a
  // few hundred KB and decoding them inline is cheaper than an isolate spawn
  // per chunk.
  static const int _inlineParseMaxChars = 32 * 1024;
  // Deltas are sent for ordinary updates; a full snapshot goes out on connect
  // and at least this often as a safety net (it also covers records relayed
  // from peers we cannot reach directly, whose timestamps predate the delta
  // window).
  static const Duration _fullSnapshotInterval = Duration(minutes: 5);
  // Delta windows start this much before the last successful send so records
  // written while a send was in flight are never skipped. Duplicates are
  // harmless: imports merge by id.
  static const Duration _deltaGrace = Duration(seconds: 10);
  static const Duration _healthCheckInterval = Duration(seconds: 10);
  static const Duration _handshakeTimeout = Duration(seconds: 6);
  static const Duration _connectionIdleTimeout = Duration(seconds: 35);
  static const Duration _pingInterval = Duration(seconds: 12);
  static const int _maxSyncRetryAttempts = 5;
  static const int _maxReconnectAttempts = 8;

  final SyncService _syncService = SyncService();
  final RecentMessageCache _messageCache =
      RecentMessageCache(ttl: const Duration(minutes: 3));
  final SyncChunkAssembler _chunkAssembler = SyncChunkAssembler();

  bool _running = false;
  RawDatagramSocket? _discoverySocket;
  ServerSocket? _server;
  Timer? _announceTimer;
  Timer? _connectionHealthTimer;
  Timer? _retryTimer;
  Timer? _discoveryRestartTimer;
  Timer? _serverRestartTimer;

  final Map<String, Timer> _reconnectTimers = {};
  final Map<String, int> _reconnectAttempts = {};

  final StreamController<LanConnectionEvent> _connectionEventController =
      StreamController<LanConnectionEvent>.broadcast();

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

  // Delta-sync bookkeeping: when the last successful send's export began
  // (any kind / full), and the tombstone total it carried so deletions still
  // trigger a delta even when no records changed.
  DateTime? _lastSentAt;
  DateTime? _lastFullSentAt;
  int _lastSentTombstoneCount = -1;
  bool _forceFullSync = false;

  Future<void> _importQueue = Future.value();

  String? _deviceId;
  String? _deviceName;
  String? _shopId;
  StreamSubscription<String>? _identitySubscription;

  @visibleForTesting
  String? testingApprovedShopId;

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

  Stream<LanConnectionEvent> get connectionEvents =>
      _connectionEventController.stream;

  Future<void> initialize() async {
    await IdentityLabel.initialize();
    _subscribeToIdentity();
    _deviceName = IdentityLabel.current;
    if (kIsWeb) return;
    await _ensureDeviceInfo();
    notifyListeners();
  }

  /// Compatibility entry point. Device aliases no longer exist: changing
  /// this label changes the signed-in person's canonical display name.
  Future<void> setDeviceName(String value) async {
    final nextValue = value.trim();
    if (nextValue.isEmpty) {
      return;
    }
    final result = await AccountService().updateDisplayName(nextValue);
    if (!result.success) {
      _lastError = result.message;
      notifyListeners();
    }
  }

  Future<void> start() async {
    if (kIsWeb) {
      return;
    }
    if (_running) {
      return;
    }
    if (!LicenseGate.isAllowed(FeatureKey.lanSync)) {
      _status = 'disabled_by_admin';
      _lastError = 'LAN sync disabled by administrator.';
      notifyListeners();
      return;
    }
    final testShopId = testingApprovedShopId;
    if (testShopId != null && testShopId.isNotEmpty) {
      _shopId = testShopId;
    } else {
      final accounts = AccountService();
      await accounts.waitForAttachIfInFlight();
      var account = accounts.current;
      if (account.stage == AccountStage.unknown &&
          !account.firebaseUnavailable) {
        await accounts.refresh();
        account = accounts.current;
      }
      final shops = ShopService();
      await shops.loadCache();
      final gate = ShopPeerGate.evaluate(
        account: account,
        cachedShopId: shops.cachedShopId,
      );
      if (!gate.isAllowed) {
        _status = gate.statusCode ?? 'account_not_approved';
        _lastError = gate.message ??
            'LAN sharing requires an approved account in this shop.';
        notifyListeners();
        return;
      }
      if (FirebaseInit.available && !account.firebaseUnavailable) {
        final binding =
            await DeviceRegistrationService().verifyCurrentBinding();
        if (!binding.isBound) {
          _status = binding.peerGateStatus;
          _lastError = binding.message;
          // Approved AccountState with a missing Firebase session is a
          // desync — refresh so routing can send the user to re-login
          // instead of leaving a confusing "device not registered" state.
          if (binding.status == DeviceBindingStatus.signedOut) {
            unawaited(AccountService().refresh());
          }
          notifyListeners();
          return;
        }
      }
      _shopId = gate.shopId;
    }
    _lastError = null;
    await _ensureDeviceInfo();
    try {
      await _bindServerSocket();
      await _bindDiscoverySocket();

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
    _running = false;
    _status = 'stopped';

    _announceTimer?.cancel();
    _announceTimer = null;
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _discoveryRestartTimer?.cancel();
    _discoveryRestartTimer = null;
    _serverRestartTimer?.cancel();
    _serverRestartTimer = null;
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();
    _reconnectAttempts.clear();

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

    _pendingSync = false;
    _lastSyncAt = null;
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = null;
    _sending = false;
    _retryAttempts = 0;
    _lastSentAt = null;
    _lastFullSentAt = null;
    _lastSentTombstoneCount = -1;
    _forceFullSync = false;
    _messageCache.clear();
    _chunkAssembler.clear();
    notifyListeners();
  }

  Future<void> onNetworkResume() async {
    if (!_running) {
      return;
    }
    await refreshLocalAddresses();
    _sendLanAnnounce();
    for (final peer in _peers.values.toList()) {
      if (!_connections.containsKey(peer.id) &&
          !_pendingConnections.contains(peer.id)) {
        _maybeConnectToLanPeer(peer);
      }
    }
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

  Future<void> _bindDiscoverySocket() async {
    final old = _discoverySocket;
    _discoverySocket = null;
    old?.close();
    final socket = await _openDiscoverySocket();
    socket.broadcastEnabled = true;
    _discoverySocket = socket;
    socket.listen(
      _handleLanDatagram,
      onError: (error) {
        _addLog('LAN discovery error: $error');
        if (_running && _discoverySocket == socket) {
          _scheduleDiscoveryRestart();
        }
      },
      onDone: () {
        if (_running && _discoverySocket == socket) {
          _scheduleDiscoveryRestart();
        }
      },
    );
  }

  Future<void> _bindServerSocket() async {
    final old = _server;
    _server = null;
    try {
      await old?.close();
    } catch (_) {
      // Best-effort close of previous server socket.
    }
    final server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      tcpPort,
      shared: true,
    );
    _server = server;
    server.listen(
      (socket) => _handleLanSocket(socket, outbound: false),
      onError: (error) {
        _addLog('LAN server error: $error');
        if (_running && _server == server) _scheduleServerRestart();
      },
      onDone: () {
        if (_running && _server == server) _scheduleServerRestart();
      },
    );
  }

  void _scheduleDiscoveryRestart() {
    _discoveryRestartTimer?.cancel();
    _discoveryRestartTimer = Timer(const Duration(seconds: 3), () async {
      if (!_running) return;
      try {
        await _bindDiscoverySocket();
        _addLog('LAN discovery socket recovered.');
      } catch (e) {
        _addLog('LAN discovery restart failed: $e');
        if (_running) _scheduleDiscoveryRestart();
      }
    });
  }

  void _scheduleServerRestart() {
    _serverRestartTimer?.cancel();
    _serverRestartTimer = Timer(const Duration(seconds: 3), () async {
      if (!_running) return;
      try {
        await _bindServerSocket();
        _addLog('LAN server socket recovered.');
      } catch (e) {
        _addLog('LAN server restart failed: $e');
        if (_running) _scheduleServerRestart();
      }
    });
  }

  void _scheduleReconnect(String peerId) {
    if (!_running || _connections.containsKey(peerId)) {
      _clearReconnectState(peerId);
      return;
    }
    final attempt = _reconnectAttempts[peerId] ?? 0;
    if (attempt >= _maxReconnectAttempts) {
      _clearReconnectState(peerId);
      return;
    }
    _reconnectTimers[peerId]?.cancel();
    final seconds = (2 << attempt).clamp(2, 30);
    _reconnectTimers[peerId] = Timer(Duration(seconds: seconds), () {
      _reconnectTimers.remove(peerId);
      _attemptReconnect(peerId);
    });
  }

  void _attemptReconnect(String peerId) {
    if (!_running ||
        _connections.containsKey(peerId) ||
        _pendingConnections.contains(peerId)) {
      _clearReconnectState(peerId);
      return;
    }
    final peer = _peers[peerId];
    if (peer == null) {
      _clearReconnectState(peerId);
      return;
    }
    _reconnectAttempts[peerId] = (_reconnectAttempts[peerId] ?? 0) + 1;
    _pendingConnections.add(peerId);
    unawaited(_connectToLanPeer(peer));
  }

  void _clearReconnectState(String peerId) {
    _reconnectAttempts.remove(peerId);
    _reconnectTimers.remove(peerId)?.cancel();
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
    if (reason == 'lan_connected') {
      // A (re)connected peer may have missed any number of deltas — give it a
      // full snapshot.
      _forceFullSync = true;
    }
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
        final remoteVersion = data['protocolVersion'];
        final remoteShopId = data['shopId'];
        if (remoteVersion != protocolVersion ||
            remoteShopId is! String ||
            remoteShopId != _shopId) {
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
      'protocolVersion': protocolVersion,
      'shopId': _shopId,
    };
    final bytes = utf8.encode(jsonEncode(data));

    // Announce to the limited broadcast address AND to every local subnet's
    // directed-broadcast address. Mobile hotspots commonly drop limited
    // 255.255.255.255 broadcasts while still delivering subnet-directed ones,
    // so covering both is what lets the host and its clients discover each
    // other reliably.
    final targets = <String>{'255.255.255.255'};
    for (final address in _localAddresses) {
      final subnetBroadcast = _subnetBroadcastFor(address);
      if (subnetBroadcast != null) {
        targets.add(subnetBroadcast);
      }
    }

    for (final target in targets) {
      try {
        socket.send(bytes, InternetAddress(target), discoveryPort);
      } catch (e) {
        _addLog('LAN announce failed to $target: $e');
      }
    }

    _pruneLanPeers();
  }

  /// Derives the IPv4 /24 directed-broadcast address for [address]
  /// (e.g. 192.168.43.1 -> 192.168.43.255). Hotspots are effectively always
  /// /24, and an extra datagram to a non-existent subnet is harmless, so this
  /// best-effort derivation is safe.
  String? _subnetBroadcastFor(String address) {
    final parts = address.split('.');
    if (parts.length != 4) {
      return null;
    }
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) {
        return null;
      }
    }
    return '${parts[0]}.${parts[1]}.${parts[2]}.255';
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

    // Both peers attempt to connect. On mobile hotspots discovery and
    // reachability are frequently one-directional (a client's UDP broadcast
    // may never reach the hotspot host, or the host cannot dial back to the
    // client), so letting only the lexicographically-smaller id initiate can
    // deadlock and leave two devices "discovered but never connected" — which
    // looks like sync silently not working. Duplicate sockets created when both
    // sides dial are de-duplicated deterministically in _registerLanConnection
    // (it keeps the smaller-id-outbound socket), so this converges to one
    // connection even when only one direction actually gets through.
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
      'protocolVersion': protocolVersion,
      'shopId': _shopId,
    };
    connection.sendJson(jsonEncode(data));
  }

  void _onLanLine(_LanConnection connection, String line) {
    connection.touch();

    // Large frames are always sync payloads/chunks — never decode them here:
    // this callback runs on the UI isolate for every received line.
    if (line.length > _inlineParseMaxChars) {
      if (connection.peerId != null) {
        unawaited(
          _handleIncomingPayload(
            line,
            fallbackSourceId: connection.peerId,
            fallbackSourceName: connection.peerName,
          ),
        );
      }
      return;
    }

    try {
      final data = jsonDecode(line);
      if (data is! Map<String, dynamic>) {
        return;
      }

      final type = data['type'];
      if (type == 'lan_hello') {
        final peerId = data['id'];
        final peerName = data['name'];
        final peerShopId = data['shopId'];
        final peerVersion = data['protocolVersion'];
        if (peerVersion != protocolVersion ||
            peerShopId is! String ||
            peerShopId != _shopId) {
          _addLog('Ignored peer outside this approved shop.');
          _handshakingConnections.remove(connection);
          unawaited(connection.close());
          return;
        }
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
    _peers[peerId] = LanPeer(
      id: peerId,
      name: peerName,
      address: remoteAddress,
      port: connection.socket.remotePort,
      lastSeen: DateTime.now(),
    );

    _clearReconnectState(peerId);
    _addLog(
      'LAN connected.',
      deviceId: peerId,
      deviceName: peerName,
    );
    if (!_connectionEventController.isClosed) {
      _connectionEventController.add(LanConnectionEvent(
        type: LanConnectionEventType.connected,
        peerId: peerId,
        peerName: peerName,
      ));
    }
    notifyListeners();

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
      if (!_connectionEventController.isClosed) {
        _connectionEventController.add(LanConnectionEvent(
          type: LanConnectionEventType.disconnected,
          peerId: peerId,
          peerName: name,
        ));
      }
      _scheduleReconnect(peerId);
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
    if (payload.isEmpty) {
      return;
    }

    // Cheap size guard: a string's UTF-8 size is always >= its char count, so
    // this only lets through payloads within ~1 frame of the limit without
    // paying a full UTF-8 encode of a multi-megabyte string just to measure.
    if (payload.length > _maxPayloadBytes) {
      _addLog('Dropped incoming frame that exceeded transport size limits.');
      return;
    }

    await _ensureDeviceInfo();
    // Chunk envelopes are bounded (~a few hundred KB) and cheap to decode, so
    // they parse inline — spawning an isolate per chunk thrashes low-RAM
    // phones when a big snapshot arrives as dozens of chunks. Only large
    // non-chunk payloads (assembled or single-frame sync data) pay for an
    // isolate.
    final inlineParse = payload.length <= _inlineParseMaxChars ||
        _looksLikeChunkFrame(payload);
    final parsed = inlineParse
        ? SyncFrameCodec.parseInbound(payload)
        : await compute(SyncFrameCodec.parseInbound, payload);

    if (parsed.chunkEnvelope != null) {
      await _handleIncomingChunk(
        parsed.chunkEnvelope!,
        fallbackSourceId: fallbackSourceId,
        fallbackSourceName: fallbackSourceName,
      );
      return;
    }

    await _handleParsedSync(
      parsed,
      fallbackSourceId: fallbackSourceId,
      fallbackSourceName: fallbackSourceName,
    );
  }

  Future<void> _handleParsedSync(
    InboundParseResult parsed, {
    String? fallbackSourceId,
    String? fallbackSourceName,
  }) async {
    final syncData = parsed.syncData;
    if (syncData == null) {
      return;
    }

    final fromId = parsed.fromId ?? fallbackSourceId ?? syncData.deviceId;
    if (fromId == _deviceId || syncData.deviceId == _deviceId) {
      return;
    }

    final messageKey = parsed.messageKey;
    if (messageKey != null && _messageCache.isDuplicate(messageKey)) {
      return;
    }
    if (messageKey != null) {
      _messageCache.remember(messageKey);
    }

    final sourceName = _resolveSourceDeviceName(
      deviceId: fromId,
      providedName: parsed.fromName ?? fallbackSourceName,
    );
    _addLog(
      'Received sync data (${_formatSyncDataSummary(syncData)}).',
      deviceId: fromId,
      deviceName: sourceName,
    );
    await _queueImport(
      syncData,
      sourceDeviceId: fromId,
      sourceDeviceName: sourceName,
    );
  }

  Future<void> _handleIncomingChunk(
    Map<String, dynamic> chunkEnvelope, {
    String? fallbackSourceId,
    String? fallbackSourceName,
  }) async {
    final fromId = chunkEnvelope['fromId']?.toString() ?? fallbackSourceId;
    if (fromId != null && fromId == _deviceId) {
      return;
    }

    final sourceName = _resolveSourceDeviceName(
      deviceId: fromId,
      providedName: chunkEnvelope['fromName']?.toString() ?? fallbackSourceName,
    );

    final messageId = chunkEnvelope['messageId']?.toString().trim();
    if (messageId == null || messageId.isEmpty) {
      _addLog(
        'Dropped sync chunk missing message id.',
        deviceId: fromId,
        deviceName: sourceName,
      );
      return;
    }

    final messageKey = SyncMessageUtils.buildMessageKey(
      messageId: messageId,
      payload: messageId,
    );
    if (_messageCache.isDuplicate(messageKey)) {
      return;
    }

    final assembly = _chunkAssembler.addEnvelope(chunkEnvelope);
    if (assembly.hasError) {
      _addLog(
        'Dropped sync chunk: ${assembly.error}',
        deviceId: fromId,
        deviceName: sourceName,
      );
      return;
    }
    if (!assembly.isComplete || assembly.payload == null) {
      return;
    }

    // The assembled payload is the full multi-megabyte sync message — parse
    // it in a background isolate.
    final parsed = await compute(SyncFrameCodec.parseInbound, assembly.payload!);
    await _handleParsedSync(
      parsed,
      fallbackSourceId: fromId,
      fallbackSourceName: sourceName,
    );
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
      // Delta by default: one sale puts a few KB on the wire instead of the
      // full dataset, which is what keeps sync realtime on slow hotspot Wi-Fi.
      // Fulls go out on peer connect and every _fullSnapshotInterval.
      final exportStartedAt = DateTime.now();
      final since = _lastSentAt?.subtract(_deltaGrace);
      final sendFull = _forceFullSync ||
          since == null ||
          _lastFullSentAt == null ||
          exportStartedAt.difference(_lastFullSentAt!) >=
              _fullSnapshotInterval;
      final data = sendFull
          ? await _syncService.exportAllData()
          : await _syncService.exportChangedSince(since);
      final tombstoneCount = _tombstoneCountOf(data);
      if (data.isEmpty &&
          (sendFull || tombstoneCount == _lastSentTombstoneCount)) {
        // Nothing new to share (an item-less delta still goes out when the
        // tombstone total moved, so deletions propagate immediately).
        return true;
      }

      final messageId = SyncMessageUtils.nextMessageId(data.deviceId);
      // Encoding + chunking the full dataset can take hundreds of
      // milliseconds; run it in a background isolate so the UI never skips a
      // frame while syncing.
      final result = await compute(
        SyncFrameCodec.buildOutboundFrames,
        OutboundFrameRequest(
          data: data,
          messageId: messageId,
          fromName: _deviceName ?? 'Device',
          sentAtIso: DateTime.now().toIso8601String(),
          maxFrameBytes: _maxPayloadBytes,
          maxTotalBytes: _maxSyncPayloadBytes,
          chunkRawBytes: SyncMessageUtils.chunkRawBytes,
        ),
      );

      if (result.error != null) {
        _lastError = result.error;
        _addLog(_lastError!);
        notifyListeners();
        return false;
      }

      final delivered = _sendFrameBatch(
        result.frames,
        failureError: result.chunkCount > 1
            ? 'Failed to send sync payload chunk.'
            : 'Failed to send sync payload.',
      );

      if (delivered == 0) {
        _addLog('No active peers were available to receive sync payload.');
        return false;
      }

      _messageCache.remember(
        SyncMessageUtils.buildMessageKey(
          messageId: messageId,
          payload: messageId,
        ),
      );
      _lastSentAt = exportStartedAt;
      if (sendFull) {
        _lastFullSentAt = exportStartedAt;
        _forceFullSync = false;
      }
      _lastSentTombstoneCount = tombstoneCount;
      final summary = _formatSyncDataSummary(data);
      final kind = sendFull ? 'full' : 'delta';
      if (result.chunkCount == 1) {
        _addLog(
          'Shared $kind sync data ($summary) to $delivered peer(s).',
        );
      } else {
        _addLog(
          'Shared $kind sync data ($summary, ${result.chunkCount} chunks) to $delivered peer(s).',
        );
      }
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

  /// Our chunk frames always serialize `type` as the first key, so this cheap
  /// prefix check identifies them without a JSON decode. A foreign frame that
  /// fails the check merely falls back to the isolate path.
  static bool _looksLikeChunkFrame(String payload) =>
      payload.startsWith('{"type":"${SyncMessageUtils.syncChunkType}"');

  int _tombstoneCountOf(SyncData data) {
    return data.deletedProductIds.length +
        data.deletedCategoryIds.length +
        data.deletedCustomerIds.length +
        data.deletedEmployeeIds.length +
        data.deletedExpenseIds.length +
        data.deletedStoreIds.length +
        data.deletedCustomerCreditEntryIds.length +
        data.deletedSaleIds.length;
  }

  int _sendFrameBatch(
    List<Uint8List> frames, {
    required String failureError,
  }) {
    if (frames.isEmpty) {
      return 0;
    }

    var delivered = 0;
    final snapshot = _connections.values.toList();
    for (final connection in snapshot) {
      var sent = true;
      for (final frame in frames) {
        if (!connection.sendFrame(frame)) {
          sent = false;
          break;
        }
      }
      if (sent) {
        delivered++;
      } else {
        _removeLanConnection(
          connection,
          error: failureError,
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
            'Applied sync data (${_formatImportSummary(result)}).',
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

  String _formatSyncDataSummary(SyncData data) {
    return '${data.totalItems} items, expenses ${data.expenses.length}';
  }

  String _formatImportSummary(SyncResult result) {
    return '${result.totalImported} imported, expenses ${result.expensesImported}';
  }

  void _runConnectionHealthCheck() {
    if (!_running) {
      return;
    }

    final now = DateTime.now();
    _messageCache.prune(now);
    _chunkAssembler.prune(now);
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

    for (final peerId in _reconnectAttempts.keys.toList()) {
      if (_connections.containsKey(peerId)) {
        _clearReconnectState(peerId);
      } else if (!_reconnectTimers.containsKey(peerId) &&
          !_pendingConnections.contains(peerId)) {
        _scheduleReconnect(peerId);
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
    await IdentityLabel.initialize();
    _subscribeToIdentity();
    _deviceName = IdentityLabel.current;
  }

  void _subscribeToIdentity() {
    _identitySubscription ??= IdentityLabel.changes.listen((name) {
      _deviceName = name;
      _addLog('Identity updated to "$name".');
      if (_running) {
        _sendLanAnnounce();
        for (final connection in _connections.values) {
          _sendLanHello(connection);
        }
      }
      notifyListeners();
    });
  }

  @visibleForTesting
  void configureApprovedShopForTesting(String? shopId) {
    testingApprovedShopId = shopId;
    if (shopId != null && shopId.isNotEmpty) {
      _shopId = shopId;
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

enum LanConnectionEventType { connected, disconnected }

@immutable
class LanConnectionEvent {
  const LanConnectionEvent({
    required this.type,
    required this.peerId,
    required this.peerName,
  });

  final LanConnectionEventType type;
  final String peerId;
  final String peerName;
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

  /// Sends a pre-encoded frame (UTF-8 JSON line including trailing newline).
  bool sendFrame(Uint8List frame) {
    if (_closed) {
      return false;
    }
    try {
      socket.add(frame);
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
