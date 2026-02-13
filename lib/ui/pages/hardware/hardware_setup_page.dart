import 'package:flutter/material.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_badge.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_section_header.dart';

class HardwareSetupPage extends StatefulWidget {
  const HardwareSetupPage({super.key});

  @override
  State<HardwareSetupPage> createState() => _HardwareSetupPageState();
}

class _HardwareSetupPageState extends State<HardwareSetupPage> {
  final List<Map<String, dynamic>> _devices = [
    {
      'name': 'Epson TM-T88V',
      'type': 'Printer',
      'status': 'Connected',
      'icon': Icons.print_outlined
    },
    {
      'name': 'Socket Mobile S700',
      'type': 'Scanner',
      'status': 'Disconnected',
      'icon': Icons.qr_code_scanner
    },
    {
      'name': 'Star Micronics',
      'type': 'Cash Drawer',
      'status': 'Connected',
      'icon': Icons.point_of_sale_outlined
    },
    {
      'name': 'Verifone P400',
      'type': 'Terminal',
      'status': 'Disconnected',
      'icon': Icons.credit_card
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Hardware',
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
        const SizedBox(width: 6),
      ],
      child: ListView(
        children: [
          const AppSectionHeader(title: 'Printers and Scanners'),
          ..._devices
              .where((d) => d['type'] == 'Printer' || d['type'] == 'Scanner')
              .map(_buildDeviceTile),
          const SizedBox(height: AppTokens.space4),
          const AppSectionHeader(title: 'Payment Terminals'),
          ..._devices
              .where((d) => d['type'] == 'Terminal')
              .map(_buildDeviceTile),
          const SizedBox(height: AppTokens.space4),
          const AppSectionHeader(title: 'Other Devices'),
          ..._devices
              .where((d) => d['type'] == 'Cash Drawer')
              .map(_buildDeviceTile),
          const SizedBox(height: AppTokens.space4),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Add New Device'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(Map<String, dynamic> device) {
    final isConnected = device['status'] == 'Connected';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space2),
      child: AppPanel(
        child: ListTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isConnected ? AppTokens.accentSoft : AppTokens.paperAlt,
              border: Border.all(
                color: isConnected ? AppTokens.accent : AppTokens.line,
              ),
            ),
            child: Icon(
              device['icon'] as IconData,
              size: 20,
              color: isConnected ? AppTokens.accent : AppTokens.mutedText,
            ),
          ),
          title: Text(device['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(device['type'] as String,
              style: const TextStyle(fontSize: 12, color: AppTokens.mutedText)),
          trailing: AppBadge(
            label: device['status'] as String,
            tone: isConnected ? AppBadgeTone.success : AppBadgeTone.neutral,
          ),
          onTap: () {},
        ),
      ),
    );
  }
}
