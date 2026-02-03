import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';

class StoresPage extends StatelessWidget {
  const StoresPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stores = [
      {'id': '1', 'name': 'Store A (Main)', 'location': 'Kigali Downtown', 'status': 'Active'},
      {'id': '2', 'name': 'Store B (Kigali)', 'location': 'Kimironko', 'status': 'Active'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stores', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (await PinProtection.requirePinIfNeeded(
            context,
            isRequired: () => PinService().isPinRequiredForAddStore(),
            title: 'Add Store',
            subtitle: 'Enter PIN to add a store',
          )) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add store feature')),
            );
          }
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: stores.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final store = stores[index];
          return ListTile(
            onTap: () async {
              if (await PinProtection.requirePinIfNeeded(
                context,
                isRequired: () => PinService().isPinRequiredForViewStores(),
                title: 'Store Details',
                subtitle: 'Enter PIN to view store details',
              )) {
                context.push('/store/${store['id']}');
              }
            },
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.store_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            title: Text(store['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(store['location'] as String, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                store['status'] as String,
                style: TextStyle(color: Colors.green[700], fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}
