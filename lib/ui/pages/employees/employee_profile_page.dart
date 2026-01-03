import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

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
        title: const Text('Employee Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Implement edit employee
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Employee Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    child: Text(
                      employee['name'].toString().substring(0, 1),
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    employee['name'] as String,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.successContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      employee['role'] as String,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  _buildInfoRow('Email', employee['email'] as String),
                  _buildInfoRow('Phone', employee['phone'] as String),
                  _buildInfoRow('Status', employee['status'] as String),
                  _buildInfoRow('Join Date', employee['joinDate'] as String),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Performance Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Performance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Total Sales', '${employee['salesCount']}'),
                  _buildInfoRow('Total Revenue', '${employee['totalSales']} RWF'),
                  _buildInfoRow('Average/Day', '${(employee['salesCount'] as int) / 30} sales'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Permissions Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Permissions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _buildPermissionRow(context, 'Process Sales', true),
                  _buildPermissionRow(context, 'Manage Inventory', false),
                  _buildPermissionRow(context, 'View Reports', false),
                  _buildPermissionRow(context, 'Manage Customers', true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement deactivate
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Deactivate Employee'),
                  content: const Text('Are you sure you want to deactivate this employee?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                      child: const Text('Deactivate'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.block),
            label: const Text('Deactivate Employee'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildPermissionRow(BuildContext context, String permission, bool enabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(permission),
          Icon(
            enabled ? Icons.check_circle : Icons.cancel,
            color: enabled ? Theme.of(context).colorScheme.success : Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }
}
