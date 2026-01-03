import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  // UUIDs for our custom service and characteristic
  static const String serviceUUID = '00001234-0000-1000-8000-00805f9b34fb';
  static const String characteristicUUID = '00005678-0000-1000-8000-00805f9b34fb';

  final StreamController<List<fbp.ScanResult>> _scanResultsController =
      StreamController<List<fbp.ScanResult>>.broadcast();
  final StreamController<String> _receivedDataController =
      StreamController<String>.broadcast();
  final StreamController<fbp.BluetoothConnectionState> _connectionStateController =
      StreamController<fbp.BluetoothConnectionState>.broadcast();

  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _characteristic;
  
  Stream<List<fbp.ScanResult>> get scanResults => _scanResultsController.stream;
  Stream<String> get receivedData => _receivedDataController.stream;
  Stream<fbp.BluetoothConnectionState> get connectionState =>
      _connectionStateController.stream;

  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;

  /// Check and request Bluetooth permissions
  Future<bool> checkPermissions() async {
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }
    if (await Permission.bluetoothAdvertise.isDenied) {
      await Permission.bluetoothAdvertise.request();
    }
    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }

    return await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted &&
        await Permission.location.isGranted;
  }

  /// Check if Bluetooth is available and turned on
  Future<bool> isBluetoothAvailable() async {
    try {
      if (await fbp.FlutterBluePlus.isSupported == false) {
        return false;
      }
      
      final adapterState = await fbp.FlutterBluePlus.adapterState.first;
      return adapterState == fbp.BluetoothAdapterState.on;
    } catch (e) {
      print('Error checking Bluetooth availability: $e');
      return false;
    }
  }

  /// Start scanning for nearby devices
  Future<void> startScanning() async {
    try {
      if (!await checkPermissions()) {
        throw Exception('Bluetooth permissions not granted');
      }

      if (!await isBluetoothAvailable()) {
        throw Exception('Bluetooth is not available or turned off');
      }

      // Stop any existing scan
      await fbp.FlutterBluePlus.stopScan();

      // Start scanning
      await fbp.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );

      // Listen to scan results
      fbp.FlutterBluePlus.scanResults.listen((results) {
        _scanResultsController.add(results);
      });
    } catch (e) {
      print('Error starting scan: $e');
      rethrow;
    }
  }

  /// Stop scanning for devices
  Future<void> stopScanning() async {
    try {
      await fbp.FlutterBluePlus.stopScan();
    } catch (e) {
      print('Error stopping scan: $e');
    }
  }

  /// Connect to a Bluetooth device
  Future<bool> connectToDevice(fbp.BluetoothDevice device) async {
    try {
      // Disconnect from current device if connected
      if (_connectedDevice != null) {
        await disconnect();
      }

      print('Connecting to ${device.platformName}...');
      
      // Connect to the device
      await device.connect(
        timeout: const Duration(seconds: 15),
      );

      _connectedDevice = device;

      // Listen to connection state changes
      device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == fbp.BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _characteristic = null;
        }
      });

      // Discover services
      List<fbp.BluetoothService> services = await device.discoverServices();
      
      // Find our custom service and characteristic
      for (fbp.BluetoothService service in services) {
        if (service.serviceUuid.toString().toLowerCase() == serviceUUID.toLowerCase()) {
          for (fbp.BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.characteristicUuid.toString().toLowerCase() ==
                characteristicUUID.toLowerCase()) {
              _characteristic = characteristic;
              
              // Subscribe to notifications
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  String data = utf8.decode(value);
                  _receivedDataController.add(data);
                }
              });
              
              break;
            }
          }
        }
      }

      print('Connected to ${device.platformName}');
      return true;
    } catch (e) {
      print('Error connecting to device: $e');
      _connectedDevice = null;
      _characteristic = null;
      return false;
    }
  }

  /// Send data to connected device
  Future<bool> sendData(String data) async {
    if (_connectedDevice == null || _characteristic == null) {
      print('No device connected or characteristic not found');
      return false;
    }

    try {
      List<int> bytes = utf8.encode(data);
      
      // Split data into chunks if too large (Bluetooth MTU limit)
      const int chunkSize = 512;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        List<int> chunk = bytes.sublist(i, end);
        await _characteristic!.write(chunk, withoutResponse: false);
        
        // Small delay between chunks
        if (end < bytes.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      print('Data sent successfully');
      return true;
    } catch (e) {
      print('Error sending data: $e');
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
        _characteristic = null;
        print('Disconnected from device');
      } catch (e) {
        print('Error disconnecting: $e');
      }
    }
  }

  /// Get list of bonded (paired) devices
  Future<List<fbp.BluetoothDevice>> getBondedDevices() async {
    try {
      return await fbp.FlutterBluePlus.bondedDevices;
    } catch (e) {
      print('Error getting bonded devices: $e');
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _scanResultsController.close();
    _receivedDataController.close();
    _connectionStateController.close();
    disconnect();
  }
}
