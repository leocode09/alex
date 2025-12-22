import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

class StoreDetailsPage extends StatelessWidget {
  final String storeId;

  const StoreDetailsPage({
    super.key,
    required this.storeId,
  });

  @override
  Widget build(BuildContext context) {
    // Mock data
    final store = {
      'name': 'Store A (Main)',
      'location': 'Kigali Downtown',
      'address': '123 Main Street, Kigali',
      'phone': '+250 788 123 456',
      'manager': 'Bob Smith',
      'employees': 5,
      'todaySales': 120000,
      'status': 'Active',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Implement edit store
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Store Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store['name'] as String,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Location', store['location'] as String),
                  _buildInfoRow('Address', store['address'] as String),
                  _buildInfoRow('Phone', store['phone'] as String),
                  _buildInfoRow('Manager', store['manager'] as String),
                  _buildInfoRow('Employees', '${store['employees']}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sales Today Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Sales',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${store['todaySales']} RWF',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.success,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
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
                  onPressed: () {
                    // TODO: View inventory
                  },
                  icon: const Icon(Icons.inventory),
                  label: const Text('Inventory'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: View employees
                  },
                  icon: const Icon(Icons.people),
                  label: const Text('Employees'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: View reports
              },
              icon: const Icon(Icons.bar_chart),
              label: const Text('View Reports'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
