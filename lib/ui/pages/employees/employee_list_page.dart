import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';
import '../../design_system/app_badge.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

class EmployeeListPage extends StatefulWidget {
  const EmployeeListPage({super.key});

  @override
  State<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  final List<Map<String, dynamic>> _employees = [
    {'id': '1', 'name': 'Alice Johnson', 'role': 'Cashier', 'status': 'Active'},
    {'id': '2', 'name': 'Bob Smith', 'role': 'Manager', 'status': 'Active'},
    {'id': '3', 'name': 'Charlie Brown', 'role': 'Stock Clerk', 'status': 'Active'},
  ];

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Employees',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (await PinProtection.requirePinIfNeeded(
            context,
            isRequired: () => PinService().isPinRequiredForAddEmployee(),
            title: 'Add Employee',
            subtitle: 'Enter PIN to add an employee',
          )) {
            if (!context.mounted) {
              return;
            }
            _showAddEmployeeDialog(context);
          }
        },
        child: const Icon(Icons.add),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _employees.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space2),
        itemBuilder: (context, index) {
          final employee = _employees[index];
          return AppPanel(
            child: ListTile(
              onTap: () async {
                if (await PinProtection.requirePinIfNeeded(
                  context,
                  isRequired: () => PinService().isPinRequiredForViewEmployees(),
                  title: 'Employee Details',
                  subtitle: 'Enter PIN to view employee details',
                )) {
                  if (!context.mounted) {
                    return;
                  }
                  context.push('/employees/${employee['id']}');
                }
              },
              leading: CircleAvatar(
                backgroundColor: AppTokens.paperAlt,
                child: Text(
                  employee['name'].toString().substring(0, 1),
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(employee['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(employee['role'] as String, style: const TextStyle(color: AppTokens.mutedText, fontSize: 12)),
              trailing: AppBadge(
                label: employee['status'] as String,
                tone: AppBadgeTone.success,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddEmployeeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String selectedRole = 'Cashier';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Employee', style: TextStyle(fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: ['Cashier', 'Manager', 'Stock Clerk', 'Admin']
                      .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => selectedRole = value);
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Employee added')),
              );
            },
            child: Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}
