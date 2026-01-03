import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sale.dart';
import 'package:intl/intl.dart';

import '../providers/receipt_provider.dart';

class PrinterService {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;
  Stream<BluetoothAdapterState> get adapterState => FlutterBluePlus.adapterState;

  Future<bool> checkPermissions() async {
    if (Platform.isAndroid) {
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();
      final locationStatus = await Permission.location.request();
      
      return scanStatus.isGranted && connectStatus.isGranted && locationStatus.isGranted;
    }
    return true;
  }

  Future<void> startScan() async {
    if (await checkPermissions()) {
      // Check if bluetooth is on
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        try {
          if (Platform.isAndroid) {
            await FlutterBluePlus.turnOn();
          }
        } catch (e) {
          print('Could not turn on Bluetooth: $e');
        }
      }
      
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );
    } else {
      throw Exception('Bluetooth permissions not granted');
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      await stopScan();
      await device.connect(autoConnect: false);
      _connectedDevice = device;
      
      // Request MTU for faster transmission
      if (Platform.isAndroid) {
        await device.requestMtu(512);
      }
      
      await _findWriteCharacteristic(device);
      
      // Listen for disconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _writeCharacteristic = null;
        }
      });
    } catch (e) {
      print('Connection error: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _writeCharacteristic = null;
    }
  }

  Future<void> _findWriteCharacteristic(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
          _writeCharacteristic = characteristic;
          return;
        }
      }
    }
    throw Exception('No write characteristic found');
  }

  Future<void> printReceipt(Sale sale, ReceiptSettings settings) async {
    if (_connectedDevice == null) {
      throw Exception('Printer not connected');
    }
    
    if (_writeCharacteristic == null) {
      await _findWriteCharacteristic(_connectedDevice!);
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Header
    bytes += generator.text(settings.shopName,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ));
    if (settings.addressLine1.isNotEmpty) {
      bytes += generator.text(settings.addressLine1, styles: const PosStyles(align: PosAlign.center));
    }
    if (settings.addressLine2.isNotEmpty) {
      bytes += generator.text(settings.addressLine2, styles: const PosStyles(align: PosAlign.center));
    }
    if (settings.phone.isNotEmpty) {
      bytes += generator.text(settings.phone, styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.hr();

    // Sale Info
    final dateFormat = DateFormat('d MMM y HH:mm');
    bytes += generator.row([
      PosColumn(text: dateFormat.format(sale.createdAt), width: 8),
      PosColumn(text: '#${sale.id.substring(0, 6)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr();

    // Items
    for (var item in sale.items) {
      bytes += generator.text(item.productName, styles: const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(text: '${item.quantity}x ${item.price.toStringAsFixed(0)}', width: 8),
        PosColumn(
          text: item.subtotal.toStringAsFixed(2),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();

    // Delivery (Placeholder for now, as it's not in Sale model yet)
    // bytes += generator.row([
    //   PosColumn(text: 'Delivery', width: 8),
    //   PosColumn(text: '0', width: 4, styles: const PosStyles(align: PosAlign.right)),
    // ]);
    // bytes += generator.hr();

    // Totals
    bytes += generator.row([
      PosColumn(text: 'Total', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
        text: sale.total.toStringAsFixed(2),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2),
      ),
    ]);

    bytes += generator.row([
      PosColumn(text: sale.paymentMethod, width: 6),
      PosColumn(
        text: sale.total.toStringAsFixed(0),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    // Change due (Placeholder)
    // bytes += generator.row([
    //   PosColumn(text: 'Change due', width: 6),
    //   PosColumn(text: '0.00', width: 6, styles: const PosStyles(align: PosAlign.right)),
    // ]);

    bytes += generator.feed(1);
    bytes += generator.text('_' * 20, styles: const PosStyles(align: PosAlign.right)); // Signature line
    
    bytes += generator.feed(1);
    bytes += generator.text(settings.footerMessage, styles: const PosStyles(align: PosAlign.center, bold: true));

    bytes += generator.feed(2);
    bytes += generator.cut();

    // Send bytes to printer
    // Split into chunks to avoid buffer overflow
    // Use a safe chunk size (e.g., 20 bytes is standard BLE, but we requested MTU 512)
    // We'll stick to a conservative 100 bytes or use the negotiated MTU if we could track it.
    const int chunkSize = 100; 
    for (var i = 0; i < bytes.length; i += chunkSize) {
      var end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      try {
        await _writeCharacteristic!.write(bytes.sublist(i, end));
        // Small delay to prevent buffer overflow on the printer side
        await Future.delayed(const Duration(milliseconds: 10)); 
      } catch (e) {
        print('Error writing chunk: $e');
        throw Exception('Failed to print chunk');
      }
    }
  }
}
