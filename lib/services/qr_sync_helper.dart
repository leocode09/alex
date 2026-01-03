import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:device_info_plus/device_info_plus.dart';

class QRSyncData {
  final String deviceId;
  final String deviceName;
  final String bluetoothAddress;
  final DateTime timestamp;

  QRSyncData({
    required this.deviceId,
    required this.deviceName,
    required this.bluetoothAddress,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'bluetoothAddress': bluetoothAddress,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory QRSyncData.fromMap(Map<String, dynamic> map) {
    return QRSyncData(
      deviceId: map['deviceId'] as String,
      deviceName: map['deviceName'] as String,
      bluetoothAddress: map['bluetoothAddress'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  String toQRString() => json.encode(toMap());

  factory QRSyncData.fromQRString(String qrString) {
    final map = json.decode(qrString) as Map<String, dynamic>;
    return QRSyncData.fromMap(map);
  }
}

class QRSyncHelper {
  /// Generate QR code data from local device
  static Future<QRSyncData> generateQRData() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceName = 'POS Device';
    String deviceId = DateTime.now().millisecondsSinceEpoch.toString();
    String bluetoothAddress = '';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use device model and manufacturer for a readable name
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
        deviceId = androidInfo.id; // Use Android ID as device ID
        
        // Try to get Bluetooth adapter address
        try {
          final adapterState = await fbp.FlutterBluePlus.adapterState.first;
          if (adapterState == fbp.BluetoothAdapterState.on) {
            // Use device ID as Bluetooth identifier
            // Note: Actual Bluetooth MAC address is not accessible on Android 6+
            bluetoothAddress = deviceId;
          }
        } catch (e) {
          print('Could not get Bluetooth info: $e');
          bluetoothAddress = deviceId;
        }
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = '${iosInfo.name} (${iosInfo.model})';
        deviceId = iosInfo.identifierForVendor ?? deviceId;
      }
    } catch (e) {
      print('Error getting device info: $e');
      // Fallback to timestamp-based ID
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    return QRSyncData(
      deviceId: deviceId,
      deviceName: deviceName,
      bluetoothAddress: bluetoothAddress,
      timestamp: DateTime.now(),
    );
  }

  /// Parse scanned QR code
  static QRSyncData? parseQRCode(String qrCode) {
    try {
      return QRSyncData.fromQRString(qrCode);
    } catch (e) {
      print('Error parsing QR code: $e');
      return null;
    }
  }

  /// Validate QR code (check if it's not too old)
  static bool isQRCodeValid(QRSyncData data, {Duration maxAge = const Duration(minutes: 5)}) {
    final age = DateTime.now().difference(data.timestamp);
    return age <= maxAge;
  }
}
