import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  final _searchController = TextEditingController();

  final List<Map<String, dynamic>> _customers = [
    {'id': '1', 'name': 'John Doe', 'purchases': 12, 'phone': '+250 788 123 456'},
    {'id': '2', 'name': 'Mary Jane', 'purchases': 4, 'phone': '+250 788 234 567'},
    {'id': '3', 'name': 'Peter Smith', 'purchases': 8, 'phone': '+250 788 345 678'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _customers.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final customer = _customers[index];
                return ListTile(
                  onTap: () async {
                    if (await PinProtection.requirePinIfNeeded(
                      context,
                      isRequired: () => PinService().isPinRequiredForViewCustomers(),
                      title: 'Customer Details',
                      subtitle: 'Enter PIN to view customer details',
                    )) {
                      if (!context.mounted) {
                        return;
                      }
                      context.push('/customer/${customer['id']}');
                    }
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    child: Text(
                      customer['name'].toString().substring(0, 1),
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(customer['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '${customer['purchases']} purchases • ${customer['phone']}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
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
        title: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement add customer
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Customer added')),
              );
            },
            child: Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}
