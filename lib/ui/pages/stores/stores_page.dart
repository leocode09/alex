import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../themes/app_theme.dart';

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
        title: const Text('Multi-Store Management'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: stores.length,
        itemBuilder: (context, index) {
          final store = stores[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.store, size: 40),
              title: Text(store['name'] as String),
              subtitle: Text(store['location'] as String),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.successContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      store['status'] as String,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.success,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              onTap: () => context.push('/store/${store['id']}'),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement add store
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add store feature')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Store'),
      ),
    );
  }
}
