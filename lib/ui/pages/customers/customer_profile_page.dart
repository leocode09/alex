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
        title: const Text('Customer Profile', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // TODO: Implement edit customer
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[200],
                    child: Text(
                      customer['name'].toString().substring(0, 1),
                      style: TextStyle(fontSize: 32, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    customer['name'] as String,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(customer['phone'] as String, style: TextStyle(color: Colors.grey[600])),
                  Text(customer['email'] as String, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Stats
            Row(
              children: [
                Expanded(child: _buildStatItem('Purchases', '${customer['totalPurchases']}')),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                Expanded(child: _buildStatItem('Spent', '${customer['totalSpent']} RWF')),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                Expanded(child: _buildStatItem('Joined', customer['joinDate'] as String)),
              ],
            ),
            const SizedBox(height: 32),

            // Recent Purchases
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Purchases', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: recentPurchases.map((purchase) => Column(
                  children: [
                    ListTile(
                      title: Text('${purchase['amount']} RWF', style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('${purchase['items']} items', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      trailing: Text(purchase['date'] as String, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ),
                    if (purchase != recentPurchases.last) const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                )).toList(),
              ),
            ),
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
}
