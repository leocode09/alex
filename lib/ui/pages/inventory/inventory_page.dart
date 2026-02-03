import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lowStockItems = [
      {'name': 'Sugar', 'stock': 12, 'minStock': 20},
      {'name': 'Bread', 'stock': 30, 'minStock': 50},
      {'name': 'Rice', 'stock': 15, 'minStock': 30},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Summary
          Row(
            children: [
              Expanded(child: _buildSummaryCard(context, 'Total Items', '156', Icons.inventory_2_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryCard(context, 'Low Stock', '3', Icons.warning_amber_rounded, isWarning: true)),
            ],
          ),
          const SizedBox(height: 24),

          // Low Stock Alerts
          const Text('Low Stock Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: lowStockItems.map((item) => Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                    ),
                    title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      '${item['stock']} left (Min: ${item['minStock']})',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final allowed = await PinProtection.requirePinIfNeeded(
                          context,
                          isRequired: () => PinService().isPinRequiredForAdjustStock(),
                          title: 'Adjust Stock',
                          subtitle: 'Enter PIN to adjust stock levels',
                        );
                        if (!allowed) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Adding stock for ${item['name']}')),
                        );
                      },
                      child: const Text('Restock'),
                    ),
                  ),
                  if (item != lowStockItems.last) const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              )).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _buildActionTile(
            context,
            'View All Products',
            Icons.inventory_2_outlined,
            () => context.push('/products'),
          ),
          const SizedBox(height: 8),
          _buildActionTile(
            context,
            'Bulk Update',
            Icons.edit_outlined,
            () async {
              final allowed = await PinProtection.requirePinIfNeeded(
                context,
                isRequired: () => PinService().isPinRequiredForAdjustStock(),
                title: 'Bulk Update',
                subtitle: 'Enter PIN to adjust stock levels',
              );
              if (!allowed) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bulk update feature')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon, {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWarning ? Colors.orange[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isWarning ? Colors.orange[100]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isWarning ? Colors.orange[700] : Theme.of(context).colorScheme.primary, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isWarning ? Colors.orange[900] : Colors.black87,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: isWarning ? Colors.orange[800] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
    );
  }
}
