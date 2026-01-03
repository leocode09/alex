import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/sync_provider.dart';
import '../../services/sync_service.dart';
import '../../services/qr_sync_helper.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  QRSyncData? _qrData;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndBluetooth();
    _generateQRData();
  }

  Future<void> _generateQRData() async {
    final qrData = await QRSyncHelper.generateQRData();
    setState(() {
      _qrData = qrData;
    });
  }

  Future<void> _checkPermissionsAndBluetooth() async {
    final provider = context.read<SyncProvider>();
    
    // Check permissions
    final hasPermissions = await provider.checkPermissions();
    if (!hasPermissions) {
      if (mounted) {
        _showError('Bluetooth permissions are required for syncing');
      }
      return;
    }

    // Check if Bluetooth is available
    final isAvailable = await provider.isBluetoothAvailable();
    if (!isAvailable) {
      if (mounted) {
        _showError('Please turn on Bluetooth');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showQRCodeDialog() {
    if (_qrData == null) {
      _showError('QR code not ready yet');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan to Connect'),
        content: SizedBox(
          width: 300,
          height: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: _qrData!.toQRString(),
                version: QrVersions.auto,
                size: 250.0,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                'Device: ${_qrData!.deviceName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan this QR code from another device to connect quickly',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showQRScannerDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          height: 500,
          child: Column(
            children: [
              AppBar(
                title: const Text('Scan QR Code'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final code = barcodes.first.rawValue;
                      if (code != null) {
                        Navigator.pop(context);
                        _handleScannedQRCode(code);
                      }
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Point camera at QR code to connect',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleScannedQRCode(String qrCode) async {
    final qrData = QRSyncHelper.parseQRCode(qrCode);
    
    if (qrData == null) {
      _showError('Invalid QR code');
      return;
    }

    if (!QRSyncHelper.isQRCodeValid(qrData)) {
      _showError('QR code expired. Please generate a new one.');
      return;
    }

    // Show scanning status
    _showSuccess('QR code scanned! Searching for device: ${qrData.deviceName}');
    
    // Start scanning for devices
    final provider = context.read<SyncProvider>();
    await provider.startScanning();
    
    // Wait a bit for devices to be discovered
    await Future.delayed(const Duration(seconds: 3));
    
    // Try to find the device by name
    try {
      final matchingDevice = provider.scanResults.firstWhere(
        (result) {
          final deviceName = result.device.platformName.toLowerCase();
          final remoteId = result.device.remoteId.toString().toLowerCase();
          final targetName = qrData.deviceName.toLowerCase();
          final targetId = qrData.deviceId.toLowerCase();
          final targetAddress = qrData.bluetoothAddress.toLowerCase();
          
          // Match by name, ID, or Bluetooth address
          return deviceName.contains(targetName) ||
                 targetName.contains(deviceName) ||
                 remoteId.contains(targetId) ||
                 (targetAddress.isNotEmpty && remoteId.contains(targetAddress));
        },
      );

      await provider.stopScanning();
      final success = await provider.connectToDevice(matchingDevice.device);
      if (success) {
        _showSuccess('Connected to ${qrData.deviceName}!');
      } else {
        _showError('Failed to connect to ${qrData.deviceName}');
      }
    } catch (e) {
      _showError('Device not found. Make sure Bluetooth is on and devices are nearby.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Sync'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<SyncProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Connection Status Card
              _buildConnectionStatusCard(provider),
              
              // Sync Controls
              if (provider.isConnected) _buildSyncControls(provider),
              
              // Device Scanner
              if (!provider.isConnected) _buildDeviceScanner(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatusCard(SyncProvider provider) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  provider.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: provider.isConnected ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.isConnected ? 'Connected' : 'Not Connected',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (provider.connectedDevice != null)
                        Text(
                          provider.connectedDevice!.platformName.isNotEmpty
                              ? provider.connectedDevice!.platformName
                              : 'Unknown Device',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                if (provider.isConnected)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      await provider.disconnect();
                      _showSuccess('Disconnected');
                    },
                  ),
              ],
            ),
            if (provider.syncStatus != SyncStatus.idle) ...[
              const SizedBox(height: 12),
              _buildSyncStatusIndicator(provider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusIndicator(SyncProvider provider) {
    Color statusColor;
    IconData statusIcon;

    switch (provider.syncStatus) {
      case SyncStatus.syncing:
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case SyncStatus.success:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case SyncStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              provider.syncMessage.isEmpty
                  ? provider.syncStatus.toString().split('.').last
                  : provider.syncMessage,
              style: TextStyle(color: statusColor),
            ),
          ),
          if (provider.syncStatus == SyncStatus.syncing)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSyncControls(SyncProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sync Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: provider.syncStatus == SyncStatus.syncing
                  ? null
                  : () async {
                      final success = await provider.performTwoWaySync();
                      if (success) {
                        _showSuccess('Two-way sync completed');
                      } else {
                        _showError('Sync failed: ${provider.errorMessage ?? "Unknown error"}');
                      }
                    },
              icon: const Icon(Icons.sync),
              label: const Text('Two-Way Sync'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: provider.syncStatus == SyncStatus.syncing
                  ? null
                  : () async {
                      final success = await provider.sendFullSync();
                      if (success) {
                        _showSuccess('Data sent successfully');
                      } else {
                        _showError('Failed to send data');
                      }
                    },
              icon: const Icon(Icons.upload),
              label: const Text('Send My Data'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: provider.syncStatus == SyncStatus.syncing
                  ? null
                  : () async {
                      final success = await provider.requestFullSync();
                      if (success) {
                        _showSuccess('Data requested successfully');
                      } else {
                        _showError('Failed to request data');
                      }
                    },
              icon: const Icon(Icons.download),
              label: const Text('Receive Their Data'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Two-Way Sync: Exchange all data with the connected device',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceScanner(SyncProvider provider) {
    return Expanded(
      child: Column(
        children: [
          // QR Code Quick Connect Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      '⚡ Quick Connect with QR Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showQRCodeDialog,
                            icon: const Icon(Icons.qr_code),
                            label: const Text('Show My QR'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showQRScannerDialog,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan QR'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Manual Device Scanner
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Devices',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: provider.isScanning
                      ? () => provider.stopScanning()
                      : () => provider.startScanning(),
                  icon: Icon(
                    provider.isScanning ? Icons.stop : Icons.search,
                  ),
                  label: Text(
                    provider.isScanning ? 'Stop' : 'Scan',
                  ),
                ),
              ],
            ),
          ),
          if (provider.isScanning)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          Expanded(
            child: provider.scanResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          provider.isScanning
                              ? 'Scanning for devices...'
                              : 'Tap Scan to find devices',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: provider.scanResults.length,
                    itemBuilder: (context, index) {
                      final result = provider.scanResults[index];
                      final device = result.device;
                      final deviceName = device.platformName.isNotEmpty
                          ? device.platformName
                          : 'Unknown Device';

                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(deviceName),
                        subtitle: Text(device.remoteId.toString()),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await provider.stopScanning();
                            final success =
                                await provider.connectToDevice(device);
                            if (success) {
                              _showSuccess('Connected to $deviceName');
                            } else {
                              _showError('Failed to connect to $deviceName');
                            }
                          },
                          child: const Text('Connect'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
