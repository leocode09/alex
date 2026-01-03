import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

class HardwareSetupPage extends StatefulWidget {
  const HardwareSetupPage({super.key});

  @override
  State<HardwareSetupPage> createState() => _HardwareSetupPageState();
}

class _HardwareSetupPageState extends State<HardwareSetupPage> {
  final Map<String, bool> _deviceStatus = {
    'Barcode Scanner': false,
    'Receipt Printer': true,
    'Cash Drawer': false,
    'Card Reader': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware Setup'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connected Devices',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ..._deviceStatus.entries.map((entry) {
                    return _buildDeviceRow(
                      context,
                      _getDeviceIcon(entry.key),
                      entry.key,
                      entry.value,
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Make sure Bluetooth is enabled on your device\n'
                    '• Keep hardware devices within range\n'
                    '• For USB devices, ensure proper drivers are installed\n'
                    '• Tap "Connect" to pair new devices',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceRow(BuildContext context, IconData icon, String name, bool connected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  connected ? 'Connected' : 'Not Connected',
                  style: TextStyle(
                    color: connected ? Theme.of(context).colorScheme.success : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _deviceStatus[name] = !_deviceStatus[name]!;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _deviceStatus[name]!
                        ? '$name connected'
                        : '$name disconnected',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: connected ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.success,
            ),
            child: Text(connected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String deviceName) {
    switch (deviceName) {
      case 'Barcode Scanner':
        return Icons.qr_code_scanner;
      case 'Receipt Printer':
        return Icons.print;
      case 'Cash Drawer':
        return Icons.inventory_2;
      case 'Card Reader':
        return Icons.credit_card;
      default:
        return Icons.devices;
    }
  }
}
