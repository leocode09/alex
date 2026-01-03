import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../themes/app_theme.dart';

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
        title: const Text('Inventory Management'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Low Stock Alerts Section
          Card(
            color: Theme.of(context).colorScheme.warningContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Theme.of(context).colorScheme.warning),
                      const SizedBox(width: 8),
                      Text(
                        'Low Stock Alerts',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...lowStockItems.map((item) => ListTile(
                        title: Text(item['name'] as String),
                        subtitle: Text('Only ${item['stock']} left (Min: ${item['minStock']})'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            // TODO: Implement add stock
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Adding stock for ${item['name']}')),
                            );
                          },
                          child: const Text('Add Stock'),
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/products'),
                  icon: const Icon(Icons.inventory),
                  label: const Text('View All Products'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement bulk update
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bulk update feature')),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Bulk Update'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Inventory Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventory Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Total Products', '45'),
                  _buildSummaryRow('Low Stock Items', '4', Theme.of(context).colorScheme.warning),
                  _buildSummaryRow('Out of Stock', '0', Theme.of(context).colorScheme.error),
                  _buildSummaryRow('Total Value', '2,450,000 RWF', Theme.of(context).colorScheme.success),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
