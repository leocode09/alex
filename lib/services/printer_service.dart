import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sale.dart';
import 'package:intl/intl.dart';

import '../providers/receipt_provider.dart';

class PrinterService {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  bool _useWriteWithoutResponse = false;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  Future<bool> checkPermissions() async {
    if (Platform.isAndroid) {
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();
      final locationStatus = await Permission.location.request();

      return scanStatus.isGranted &&
          connectStatus.isGranted &&
          locationStatus.isGranted;
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

      // Request MTU for faster transmission (optional, may fail on some devices)
      if (Platform.isAndroid) {
        try {
          await device.requestMtu(512);
        } catch (e) {
          print('MTU request failed (non-critical): $e');
        }
      }

      // Small delay to ensure connection is stable before discovering services
      await Future.delayed(const Duration(milliseconds: 500));

      await _findWriteCharacteristic(device);

      // Listen for disconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _writeCharacteristic = null;
          _useWriteWithoutResponse = false;
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
      _useWriteWithoutResponse = false;
    }
  }

  // Known thermal printer service and characteristic UUIDs
  static const List<String> _knownPrinterServiceUuids = [
    '0000ff00-0000-1000-8000-00805f9b34fb', // Common Chinese printers
    '49535343-fe7d-4ae5-8fa9-9fafd205e455', // ISSC Serial Port Service
    'e7810a71-73ae-499d-8c15-faa9aef0c3f2', // Some thermal printers
    '000018f0-0000-1000-8000-00805f9b34fb', // Some ESC/POS printers
  ];

  static const List<String> _knownPrinterCharacteristicUuids = [
    '0000ff02-0000-1000-8000-00805f9b34fb', // Common Chinese printers write characteristic
    '49535343-8841-43f4-a8d4-ecbe34729bb3', // ISSC write characteristic
    'bef8d6c9-9c21-4c9e-b632-bd58c1009f9f', // Some thermal printers
    '00002af1-0000-1000-8000-00805f9b34fb', // Some ESC/POS printers
  ];

  bool _isKnownPrinterService(String uuid) {
    final lowerUuid = uuid.toLowerCase();
    return _knownPrinterServiceUuids.any((known) => lowerUuid.contains(known.toLowerCase()));
  }

  bool _isKnownPrinterCharacteristic(String uuid) {
    final lowerUuid = uuid.toLowerCase();
    return _knownPrinterCharacteristicUuids.any((known) => lowerUuid.contains(known.toLowerCase()));
  }

  Future<void> _findWriteCharacteristic(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    
    BluetoothCharacteristic? fallbackCharacteristic;
    bool fallbackUseWithoutResponse = false;

    // Log all services and characteristics for debugging
    for (var service in services) {
      print('Service: ${service.uuid}');
      for (var characteristic in service.characteristics) {
        print('  Characteristic: ${characteristic.uuid}, props: ${characteristic.properties}');
      }
    }

    // First pass: Look for known printer characteristics
    for (var service in services) {
      final isKnownService = _isKnownPrinterService(service.uuid.toString());
      
      for (var characteristic in service.characteristics) {
        try {
          final props = characteristic.properties;
          final isKnownChar = _isKnownPrinterCharacteristic(characteristic.uuid.toString());
          final isWritable = props.write || props.writeWithoutResponse;
          
          if (!isWritable) continue;

          // If this is a known printer characteristic, use it immediately
          if (isKnownChar || isKnownService) {
            _writeCharacteristic = characteristic;
            _useWriteWithoutResponse = props.writeWithoutResponse;
            print('Using known printer characteristic: ${characteristic.uuid} (writeWithoutResponse: $_useWriteWithoutResponse)');
            return;
          }

          // Store as fallback if it's writable
          if (fallbackCharacteristic == null || props.writeWithoutResponse) {
            fallbackCharacteristic = characteristic;
            fallbackUseWithoutResponse = props.writeWithoutResponse;
          }
        } catch (e) {
          continue;
        }
      }
    }

    // Use fallback if no known characteristic found
    if (fallbackCharacteristic != null) {
      _writeCharacteristic = fallbackCharacteristic;
      _useWriteWithoutResponse = fallbackUseWithoutResponse;
      print('Using fallback characteristic: ${fallbackCharacteristic.uuid} (writeWithoutResponse: $_useWriteWithoutResponse)');
      return;
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
      bytes += generator.text(settings.addressLine1,
          styles: const PosStyles(align: PosAlign.center));
    }
    if (settings.addressLine2.isNotEmpty) {
      bytes += generator.text(settings.addressLine2,
          styles: const PosStyles(align: PosAlign.center));
    }
    if (settings.phone.isNotEmpty) {
      bytes += generator.text(settings.phone,
          styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.hr();

    // Sale Info
    final dateFormat = DateFormat('d MMM y HH:mm');
    bytes += generator.row([
      PosColumn(text: dateFormat.format(sale.createdAt), width: 8),
      PosColumn(
          text: '#${sale.id.substring(0, 6)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr();

    // Customer Info
    if (sale.customerId != null) {
      bytes += generator.text('Customer: ${sale.customerId}',
          styles: const PosStyles(bold: false));
      bytes += generator.feed(1);
    }

    // Items
    for (var item in sale.items) {
      bytes +=
          generator.text(item.productName, styles: const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(
            text: '${item.quantity}x \$${item.price.toStringAsFixed(2)}',
            width: 8),
        PosColumn(
          text: '\$${item.subtotal.toStringAsFixed(2)}',
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
      PosColumn(
          text: 'Total',
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
        text: '\$${sale.total.toStringAsFixed(2)}',
        width: 6,
        styles: const PosStyles(
            align: PosAlign.right, bold: true, height: PosTextSize.size2),
      ),
    ]);

    bytes += generator.row([
      PosColumn(text: sale.paymentMethod, width: 6),
      PosColumn(
        text: '\$${sale.total.toStringAsFixed(2)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    // Cash received and change for cash payments
    if (sale.paymentMethod == 'Cash' && sale.cashReceived != null) {
      bytes += generator.row([
        PosColumn(text: 'Cash Received', width: 6),
        PosColumn(
          text: '\$${sale.cashReceived!.toStringAsFixed(2)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      if (sale.change != null && sale.change! > 0) {
        bytes += generator.row([
          PosColumn(
              text: 'Change Due',
              width: 6,
              styles: const PosStyles(bold: true)),
          PosColumn(
            text: '\$${sale.change!.toStringAsFixed(2)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]);
      } else if (sale.cashReceived! < sale.total) {
        final amountDue = sale.total - sale.cashReceived!;
        bytes += generator.row([
          PosColumn(
              text: 'Amount Due',
              width: 6,
              styles: const PosStyles(bold: true)),
          PosColumn(
            text: '\$${amountDue.toStringAsFixed(2)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]);
      }
    }

    bytes += generator.feed(1);
    bytes += generator.text('_' * 20,
        styles: const PosStyles(align: PosAlign.right)); // Signature line

    bytes += generator.feed(1);
    bytes += generator.text(settings.footerMessage,
        styles: const PosStyles(align: PosAlign.center, bold: true));

    bytes += generator.feed(2);
    bytes += generator.cut();

    // Send bytes to printer using the appropriate write method
    await _sendBytesToPrinter(bytes);
  }

  /// Test print function to verify printer connectivity
  Future<void> testPrint() async {
    if (_connectedDevice == null) {
      throw Exception('Printer not connected');
    }

    if (_writeCharacteristic == null) {
      await _findWriteCharacteristic(_connectedDevice!);
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += generator.text('*** TEST PRINT ***',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ));
    bytes += generator.feed(1);
    bytes += generator.text('Printer is working!',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);
    bytes += generator.text(DateTime.now().toString(),
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(3);
    bytes += generator.cut();

    await _sendBytesToPrinter(bytes);
  }

  /// Sends bytes to the connected printer in chunks
  Future<void> _sendBytesToPrinter(List<int> bytes) async {
    if (_writeCharacteristic == null) {
      throw Exception('Write characteristic not available');
    }

    // ESC/POS initialize command - reset printer to default state
    final initCommand = [0x1B, 0x40]; // ESC @
    
    // Prepend initialization command
    final dataToSend = [...initCommand, ...bytes];

    print('Sending ${dataToSend.length} bytes to printer...');
    print('Using characteristic: ${_writeCharacteristic!.uuid}');
    print('Write without response: $_useWriteWithoutResponse');

    // Use a smaller chunk size for better compatibility
    // Many thermal printers work better with smaller chunks
    const int chunkSize = 20;
    
    for (var i = 0; i < dataToSend.length; i += chunkSize) {
      var end = (i + chunkSize < dataToSend.length) ? i + chunkSize : dataToSend.length;
      final chunk = dataToSend.sublist(i, end);
      
      try {
        // Try writeWithoutResponse first if supported, as it's more reliable for printers
        await _writeCharacteristic!.write(
          chunk,
          withoutResponse: _useWriteWithoutResponse,
        );
        // Longer delay between chunks for reliability
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        print('Error writing chunk at offset $i: $e');
        // Try with the opposite write mode as fallback
        try {
          await _writeCharacteristic!.write(
            chunk,
            withoutResponse: !_useWriteWithoutResponse,
          );
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e2) {
          print('Fallback write also failed: $e2');
          throw Exception('Failed to print: $e');
        }
      }
    }
    
    print('Print data sent successfully');
    // Final delay to ensure all data is processed
    await Future.delayed(const Duration(milliseconds: 200));
  }
}
