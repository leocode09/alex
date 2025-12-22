import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

class PromotionsPage extends StatelessWidget {
  const PromotionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final promotions = [
      {
        'title': '10% OFF on Bread',
        'description': 'Valid until Dec 31, 2024',
        'type': 'Discount',
        'active': true,
      },
      {
        'title': 'Buy 2 Get 1 Free - Soda',
        'description': 'Valid for all soda products',
        'type': 'Bundle',
        'active': true,
      },
      {
        'title': 'Happy Hour Special',
        'description': '20% off 5PM - 7PM',
        'type': 'Time-based',
        'active': false,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyalty & Promotions'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Active Promotions
          ...promotions.map((promo) {
            return Card(
              child: ListTile(
                leading: Icon(
                  Icons.local_offer,
                  color: promo['active'] as bool ? Theme.of(context).colorScheme.success : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  size: 32,
                ),
                title: Text(promo['title'] as String),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(promo['description'] as String),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        promo['type'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Switch(
                  value: promo['active'] as bool,
                  onChanged: (value) {
                    // TODO: Toggle promotion status
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value ? 'Promotion activated' : 'Promotion deactivated',
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 16),

          // Loyalty Program Card
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.card_giftcard, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        'Loyalty Program',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Reward your loyal customers with points and special offers'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Configure loyalty program
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Configure loyalty program')),
                      );
                    },
                    child: const Text('Configure Program'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddPromotionDialog(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Promotion'),
      ),
    );
  }

  void _showAddPromotionDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Promotion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Promotion added')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
