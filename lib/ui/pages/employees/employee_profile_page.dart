import 'package:flutter/material.dart';

class EmployeeProfilePage extends StatelessWidget {
  final String employeeId;

  const EmployeeProfilePage({
    super.key,
    required this.employeeId,
  });

  @override
  Widget build(BuildContext context) {
    // Mock data
    final employee = {
      'name': 'Alice Johnson',
      'email': 'alice@example.com',
      'phone': '+250 788 123 456',
      'role': 'Cashier',
      'status': 'Active',
      'joinDate': '2024-01-15',
      'salesCount': 245,
      'totalSales': 4500000,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Profile', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // TODO: Implement edit employee
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
                      employee['name'].toString().substring(0, 1),
                      style: const TextStyle(fontSize: 32, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    employee['name'] as String,
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
                      employee['role'] as String,
                      style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(employee['email'] as String, style: TextStyle(color: Colors.grey[600])),
                  Text(employee['phone'] as String, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Stats
            Row(
              children: [
                Expanded(child: _buildStatItem('Sales', '${employee['salesCount']}')),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                Expanded(child: _buildStatItem('Revenue', '${(employee['totalSales'] as int) ~/ 1000}K RWF')),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                Expanded(child: _buildStatItem('Joined', employee['joinDate'] as String)),
              ],
            ),
            const SizedBox(height: 32),

            // Performance
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildPerformanceRow('Total Sales', '${employee['salesCount']}'),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildPerformanceRow('Total Revenue', '${employee['totalSales']} RWF'),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildPerformanceRow('Average/Day', '${(employee['salesCount'] as int) ~/ 30} sales'),
                ],
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

  Widget _buildPerformanceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
