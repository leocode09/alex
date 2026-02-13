import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_search_field.dart';

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  final _searchController = TextEditingController();

  final List<Map<String, dynamic>> _customers = [
    {
      'id': '1',
      'name': 'John Doe',
      'purchases': 12,
      'phone': '+250 788 123 456'
    },
    {
      'id': '2',
      'name': 'Mary Jane',
      'purchases': 4,
      'phone': '+250 788 234 567'
    },
    {
      'id': '3',
      'name': 'Peter Smith',
      'purchases': 8,
      'phone': '+250 788 345 678'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Customers',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (await PinProtection.requirePinIfNeeded(
            context,
            isRequired: () => PinService().isPinRequiredForAddCustomer(),
            title: 'Add Customer',
            subtitle: 'Enter PIN to add a customer',
          )) {
            if (!context.mounted) {
              return;
            }
            _showAddCustomerDialog(context);
          }
        },
        child: const Icon(Icons.add),
      ),
      child: Column(
        children: [
          AppSearchField(
            controller: _searchController,
            hintText: 'Search customers...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppTokens.space2),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _customers.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppTokens.space2),
              itemBuilder: (context, index) {
                final customer = _customers[index];
                return AppPanel(
                  child: ListTile(
                    onTap: () async {
                      if (await PinProtection.requirePinIfNeeded(
                        context,
                        isRequired: () =>
                            PinService().isPinRequiredForViewCustomers(),
                        title: 'Customer Details',
                        subtitle: 'Enter PIN to view customer details',
                      )) {
                        if (!context.mounted) {
                          return;
                        }
                        context.push('/customers/${customer['id']}');
                      }
                    },
                    leading: CircleAvatar(
                      backgroundColor: AppTokens.paperAlt,
                      child: Text(
                        customer['name'].toString().substring(0, 1),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(customer['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${customer['purchases']} purchases - ${customer['phone']}',
                      style: const TextStyle(
                          color: AppTokens.mutedText, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Customer',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
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
                const SnackBar(content: Text('Customer added')),
              );
            },
            child: Text('Save',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}
