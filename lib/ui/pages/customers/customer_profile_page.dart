import 'package:flutter/material.dart';

class CustomerProfilePage extends StatelessWidget {
  final String customerId;

  const CustomerProfilePage({
    super.key,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context) {
    // Mock data
    final customer = {
      'name': 'John Doe',
      'phone': '+250 788 123 456',
      'email': 'john.doe@example.com',
      'totalPurchases': 12,
      'totalSpent': 45000,
      'joinDate': '2024-01-15',
    };

    final recentPurchases = [
      {'date': '2024-12-10', 'amount': 5000, 'items': 3},
      {'date': '2024-12-08', 'amount': 3500, 'items': 2},
      {'date': '2024-12-05', 'amount': 8000, 'items': 5},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Implement edit customer
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Customer Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    child: Text(
                      customer['name'].toString().substring(0, 1),
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    customer['name'] as String,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(customer['phone'] as String),
                  Text(customer['email'] as String),
                  const SizedBox(height: 16),
                  const Divider(),
                  _buildInfoRow('Total Purchases', '${customer['totalPurchases']}'),
                  _buildInfoRow('Total Spent', '${customer['totalSpent']} RWF'),
                  _buildInfoRow('Member Since', customer['joinDate'] as String),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recent Purchases
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Purchases',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ...recentPurchases.map((purchase) => ListTile(
                        title: Text('${purchase['amount']} RWF'),
                        subtitle: Text('${purchase['items']} items'),
                        trailing: Text(purchase['date'] as String),
                      )).toList(),
                ],
              ),
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
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
