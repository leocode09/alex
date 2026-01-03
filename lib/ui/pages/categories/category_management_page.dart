import 'package:flutter/material.dart';

class CategoryManagementPage extends StatelessWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      'Electronics',
      'Clothing',
      'Food & Beverages',
      'Home & Garden',
      'Sports',
      'Books',
      'Toys',
      'Other',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Management'),
      ),
      body: ListView.builder(
        itemCount: categories.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final category = categories[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.category),
              ),
              title: Text(
                category,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}
