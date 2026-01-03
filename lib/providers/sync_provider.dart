import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../services/bluetooth_service.dart';
import '../services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  final BluetoothService _bluetoothService = BluetoothService();
  final SyncService _syncService = SyncService();

  List<fbp.ScanResult> _scanResults = [];
  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothConnectionState _connectionState =
      fbp.BluetoothConnectionState.disconnected;
  bool _isScanning = false;
  SyncStatus _syncStatus = SyncStatus.idle;
  String _syncMessage = '';
  String? _errorMessage;

  List<fbp.ScanResult> get scanResults => _scanResults;
  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;
  fbp.BluetoothConnectionState get connectionState => _connectionState;
  bool get isScanning => _isScanning;
  bool get isConnected =>
      _connectionState == fbp.BluetoothConnectionState.connected;
  SyncStatus get syncStatus => _syncStatus;
  String get syncMessage => _syncMessage;
  String? get errorMessage => _errorMessage;

  SyncProvider() {
    _initialize();
  }

  void _initialize() {
    // Initialize sync service
    _syncService.initialize();

    // Listen to scan results
    _bluetoothService.scanResults.listen((results) {
      _scanResults = results;
      notifyListeners();
    });

    // Listen to connection state
    _bluetoothService.connectionState.listen((state) {
      _connectionState = state;
      if (state == fbp.BluetoothConnectionState.connected) {
        _connectedDevice = _bluetoothService.connectedDevice;
      } else {
        _connectedDevice = null;
      }
      notifyListeners();
    });

    // Listen to sync status
    _syncService.syncStatus.listen((status) {
      _syncStatus = status;
      notifyListeners();
    });

    // Listen to sync messages
    _syncService.syncMessage.listen((message) {
      _syncMessage = message;
      notifyListeners();
    });
  }

  /// Check Bluetooth permissions
  Future<bool> checkPermissions() async {
    try {
      _errorMessage = null;
      final hasPermissions = await _bluetoothService.checkPermissions();
      if (!hasPermissions) {
        _errorMessage = 'Bluetooth permissions not granted';
      }
      notifyListeners();
      return hasPermissions;
    } catch (e) {
      _errorMessage = 'Error checking permissions: $e';
      notifyListeners();
      return false;
    }
  }

  /// Check if Bluetooth is available
  Future<bool> isBluetoothAvailable() async {
    try {
      return await _bluetoothService.isBluetoothAvailable();
    } catch (e) {
      _errorMessage = 'Error checking Bluetooth: $e';
      notifyListeners();
      return false;
    }
  }

  /// Start scanning for devices
  Future<void> startScanning() async {
    try {
      _errorMessage = null;
      _isScanning = true;
      notifyListeners();

      await _bluetoothService.startScanning();
    } catch (e) {
      _errorMessage = 'Error scanning: $e';
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    try {
      await _bluetoothService.stopScanning();
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error stopping scan: $e';
      notifyListeners();
    }
  }

  /// Connect to a device
  Future<bool> connectToDevice(fbp.BluetoothDevice device) async {
    try {
      _errorMessage = null;
      notifyListeners();

      final success = await _bluetoothService.connectToDevice(device);
      
      if (!success) {
        _errorMessage = 'Failed to connect to device';
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Error connecting: $e';
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    try {
      await _bluetoothService.disconnect();
      _connectedDevice = null;
      _connectionState = fbp.BluetoothConnectionState.disconnected;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error disconnecting: $e';
      notifyListeners();
    }
  }

  /// Send full sync to connected device
  Future<bool> sendFullSync() async {
    try {
      _errorMessage = null;
      notifyListeners();
      
      final success = await _syncService.sendFullSync();
      
      if (!success && _syncStatus == SyncStatus.error) {
        _errorMessage = _syncMessage;
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Error sending sync: $e';
      notifyListeners();
      return false;
    }
  }

  /// Request full sync from connected device
  Future<bool> requestFullSync() async {
    try {
      _errorMessage = null;
      notifyListeners();
      
      final success = await _syncService.requestFullSync();
      
      if (!success && _syncStatus == SyncStatus.error) {
        _errorMessage = _syncMessage;
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Error requesting sync: $e';
      notifyListeners();
      return false;
    }
  }

  /// Perform two-way sync
  Future<bool> performTwoWaySync() async {
    try {
      _errorMessage = null;
      notifyListeners();

      // First, send our data
      bool sendSuccess = await _syncService.sendFullSync();
      if (!sendSuccess) {
        _errorMessage = 'Failed to send data';
        notifyListeners();
        return false;
      }

      // Wait a bit for the data to be processed
      await Future.delayed(const Duration(milliseconds: 500));

      // Then request their data
      bool requestSuccess = await _syncService.requestFullSync();
      if (!requestSuccess) {
        _errorMessage = 'Failed to request data';
        notifyListeners();
        return false;
      }

      return true;
    } catch (e) {
      _errorMessage = 'Error performing sync: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get list of bonded devices
  Future<List<fbp.BluetoothDevice>> getBondedDevices() async {
    try {
      return await _bluetoothService.getBondedDevices();
    } catch (e) {
      _errorMessage = 'Error getting bonded devices: $e';
      notifyListeners();
      return [];
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _bluetoothService.dispose();
    _syncService.dispose();
    super.dispose();
  }
}
