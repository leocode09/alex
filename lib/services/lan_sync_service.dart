import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/sync_data.dart';
import 'sync_service.dart';

class LanSyncService extends ChangeNotifier {
  LanSyncService._internal();

  static final LanSyncService _instance = LanSyncService._internal();

  factory LanSyncService() => _instance;

  static const int defaultPort = 42114;

  final SyncService _syncService = SyncService();

  ServerSocket? _server;
  bool _serverRunning = false;
  final List<_LanConnection> _clients = [];

  Socket? _clientSocket;
  StreamSubscription<String>? _clientSubscription;
  bool _clientConnecting = false;

  String _status = 'stopped';
  String? _lastError;

  final List<String> _logs = [];
  List<String> _localAddresses = [];

  final Duration _syncDebounce = const Duration(milliseconds: 800);
  final Duration _minSyncInterval = const Duration(seconds: 3);
  Timer? _syncDebounceTimer;
  bool _pendingSync = false;
  DateTime? _lastSyncAt;
  bool _sending = false;

  Future<void> _importQueue = Future.value();

  String? _deviceId;
  String? _deviceName;

  bool get isServerRunning => _serverRunning;
  bool get isClientConnecting => _clientConnecting;
  bool get isClientConnected => _clientSocket != null;
  bool get isConnected => isClientConnected || _clients.isNotEmpty;
  String get status => _status;
  String? get lastError => _lastError;
  List<String> get localAddresses => List.unmodifiable(_localAddresses);
  List<String> get logs => List.unmodifiable(_logs);
  List<String> get connectedClients =>
      _clients.map((client) => client.label).toList();

  Future<void> startServer({int port = defaultPort}) async {
    if (kIsWeb) {
      return;
    }
    if (_serverRunning) {
      return;
    }
    _lastError = null;
    try {
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      _serverRunning = true;
      _status = 'server_listening';
      _addLog('LAN server listening on $port');
      notifyListeners();
      await refreshLocalAddresses();
      _server?.listen(
        _handleServerConnection,
        onError: (error) {
          _lastError = error.toString();
          _addLog('Server error: $error');
          notifyListeners();
        },
        onDone: () {
          _serverRunning = false;
          _status = isClientConnected ? 'client_connected' : 'stopped';
          notifyListeners();
        },
      );
    } catch (e) {
      _serverRunning = false;
      _status = 'server_failed';
      _lastError = e.toString();
      _addLog('Server failed: $e');
      notifyListeners();
    }
  }

  Future<void> stopServer() async {
    if (!_serverRunning) {
      return;
    }
    try {
      await _server?.close();
    } catch (_) {}
    _server = null;
    _serverRunning = false;
    _closeAllClients();
    _status = isClientConnected ? 'client_connected' : 'stopped';
    notifyListeners();
  }

  Future<void> connectToHost(
    String host, {
    int port = defaultPort,
  }) async {
    if (kIsWeb) {
      return;
    }
    if (host.trim().isEmpty || _clientConnecting) {
      return;
    }
    _clientConnecting = true;
    _lastError = null;
    _status = 'client_connecting';
    notifyListeners();
    try {
      await disconnectClient();
      final socket = await Socket.connect(
        host.trim(),
        port,
        timeout: const Duration(seconds: 4),
      );
      socket.setOption(SocketOption.tcpNoDelay, true);
      _clientSocket = socket;
      _status = 'client_connected';
      _addLog('Connected to $host:$port');
      _clientSubscription = _listenToSocket(
        socket,
        isClient: true,
      );
      await _ensureDeviceInfo();
      _flushPendingSync();
    } catch (e) {
      _lastError = e.toString();
      _status = 'client_connect_failed';
      _addLog('Client connect failed: $e');
    } finally {
      _clientConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnectClient() async {
    if (_clientSocket == null) {
      return;
    }
    try {
      await _clientSubscription?.cancel();
    } catch (_) {}
    try {
      _clientSocket?.destroy();
    } catch (_) {}
    _clientSubscription = null;
    _clientSocket = null;
    _status = _serverRunning ? 'server_listening' : 'stopped';
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
      final sorted = addresses.toList()..sort();
      _localAddresses = sorted;
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      _addLog('Failed to read IPs: $e');
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
    _pendingSync = true;
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(_syncDebounce, _flushPendingSync);
  }

  void _handleServerConnection(Socket socket) {
    socket.setOption(SocketOption.tcpNoDelay, true);
    final connection = _LanConnection(socket);
    _clients.add(connection);
    _status = 'client_connected';
    _addLog('Client connected: ${connection.label}');
    notifyListeners();
    connection.subscription = _listenToSocket(socket, isClient: false, onDone: () {
      _clients.remove(connection);
      if (_clients.isEmpty) {
        _status = _serverRunning ? 'server_listening' : 'stopped';
      }
      notifyListeners();
    });
    _flushPendingSync();
  }

  StreamSubscription<String> _listenToSocket(
    Socket socket, {
    required bool isClient,
    VoidCallback? onDone,
  }) {
    return socket
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        final payload = line.trim();
        if (payload.isEmpty) {
          return;
        }
        unawaited(_handleIncomingPayload(payload));
      },
      onError: (error) {
        _addLog('Socket error: $error');
      },
      onDone: () {
        if (isClient) {
          _clientSocket = null;
          _clientSubscription = null;
          _status = _serverRunning ? 'server_listening' : 'stopped';
          notifyListeners();
        }
        onDone?.call();
      },
      cancelOnError: true,
    );
  }

  Future<void> _handleIncomingPayload(String payload) async {
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
        final fromId = json['fromId']?.toString();
        if (fromId != null && fromId == _deviceId) {
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
      await _ensureDeviceInfo();
      final data = await _syncService.exportAllData();
      if (data.isEmpty) {
        return;
      }
      final payload = jsonEncode({
        'type': 'sync_data',
        'fromId': data.deviceId,
        'fromName': _deviceName ?? 'Device',
        'sentAt': DateTime.now().toIso8601String(),
        'data': data.toJson(),
      });
      _sendPayload(payload);
    } catch (e) {
      _lastError = e.toString();
      _addLog('Send failed: $e');
      notifyListeners();
    } finally {
      _sending = false;
    }
  }

  void _sendPayload(String payload) {
    if (payload.isEmpty) {
      return;
    }
    if (_clientSocket != null) {
      _sendToSocket(_clientSocket!, payload);
    }
    if (_clients.isNotEmpty) {
      for (final connection in _clients) {
        _sendToSocket(connection.socket, payload);
      }
    }
  }

  void _sendToSocket(Socket socket, String payload) {
    try {
      socket.write('$payload\n');
    } catch (e) {
      _addLog('Send error: $e');
    }
  }

  Future<void> _flushPendingSync() async {
    if (!_pendingSync) {
      return;
    }
    if (!isConnected || _sending) {
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
        _addLog('Import failed: $e');
      }
    });
    return _importQueue;
  }

  Future<void> _ensureDeviceInfo() async {
    _deviceId ??= await _syncService.getDeviceId();
    _deviceName ??= await _getDeviceName();
  }

  Future<String> _getDeviceName() async {
    if (!Platform.isAndroid) {
      final hostname = Platform.localHostname;
      return hostname.isNotEmpty ? hostname : 'Device';
    }
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.model ?? 'Android';
    } catch (_) {
      return 'Android';
    }
  }

  void _closeAllClients() {
    for (final connection in _clients) {
      try {
        connection.subscription?.cancel();
      } catch (_) {}
      try {
        connection.socket.destroy();
      } catch (_) {}
    }
    _clients.clear();
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

class _LanConnection {
  _LanConnection(this.socket);

  final Socket socket;
  StreamSubscription<String>? subscription;

  String get label => '${socket.remoteAddress.address}:${socket.remotePort}';
}
