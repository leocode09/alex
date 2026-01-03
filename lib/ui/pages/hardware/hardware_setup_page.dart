import 'package:flutter/material.dart';

class HardwareSetupPage extends StatefulWidget {
  const HardwareSetupPage({super.key});

  @override
  State<HardwareSetupPage> createState() => _HardwareSetupPageState();
}

class _HardwareSetupPageState extends State<HardwareSetupPage> {
  // Mock data
  final List<Map<String, dynamic>> _devices = [
    {'name': 'Epson TM-T88V', 'type': 'Printer', 'status': 'Connected', 'icon': Icons.print_outlined},
    {'name': 'Socket Mobile S700', 'type': 'Scanner', 'status': 'Disconnected', 'icon': Icons.qr_code_scanner},
    {'name': 'Star Micronics', 'type': 'Cash Drawer', 'status': 'Connected', 'icon': Icons.point_of_sale_outlined},
    {'name': 'Verifone P400', 'type': 'Terminal', 'status': 'Disconnected', 'icon': Icons.credit_card},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // TODO: Scan for devices
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Printers & Scanners'),
          ..._devices.where((d) => d['type'] == 'Printer' || d['type'] == 'Scanner').map(_buildDeviceTile),

          const SizedBox(height: 24),
          _buildSectionHeader('Payment Terminals'),
          ..._devices.where((d) => d['type'] == 'Terminal').map(_buildDeviceTile),

          const SizedBox(height: 24),
          _buildSectionHeader('Other Devices'),
          ..._devices.where((d) => d['type'] == 'Cash Drawer').map(_buildDeviceTile),

          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Add New Device'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.black),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildDeviceTile(Map<String, dynamic> device) {
    final isConnected = device['status'] == 'Connected';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isConnected ? Colors.green[50] : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            device['icon'] as IconData,
            color: isConnected ? Colors.green[700] : Colors.grey[500],
            size: 20,
          ),
        ),
        title: Text(device['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(device['type'] as String, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isConnected ? Colors.green[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                device['status'] as String,
                style: TextStyle(
                  color: isConnected ? Colors.green[700] : Colors.grey[600],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.more_vert, color: Colors.grey),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}
