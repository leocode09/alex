import 'package:flutter/material.dart';

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
        title: const Text('Store Details', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // TODO: Implement edit store
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.store_outlined, size: 40, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    store['name'] as String,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      store['status'] as String,
                      style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Stats
            Row(
              children: [
                Expanded(child: _buildStatItem('Sales Today', '${(store['todaySales'] as int) ~/ 1000}K')),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                Expanded(child: _buildStatItem('Employees', '${store['employees']}')),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                Expanded(child: _buildStatItem('Manager', (store['manager'] as String).split(' ')[0])),
              ],
            ),
            const SizedBox(height: 32),

            // Details
            const Text('Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            _buildDetailRow('Location', store['location'] as String),
            _buildDetailRow('Address', store['address'] as String),
            _buildDetailRow('Phone', store['phone'] as String),
            const SizedBox(height: 32),

            // Actions
            const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildActionTile(context, 'View Inventory', Icons.inventory_2_outlined),
            _buildActionTile(context, 'View Employees', Icons.people_outline),
            _buildActionTile(context, 'Sales History', Icons.history),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, String title, IconData icon) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: () {},
    );
  }
}
