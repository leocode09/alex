import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../helpers/pin_protection.dart';
import '../../../models/product.dart';
import '../../../providers/product_provider.dart';
import '../../../services/pin_service.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  static const int _lowStockThreshold = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: productsAsync.when(
        data: (products) => _buildContent(context, ref, products),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, List<Product> products) {
    final totalProducts = products.length;
    final totalUnits = products.fold<int>(0, (sum, p) => sum + p.stock);
    final lowStockItems = products
        .where((p) => p.stock > 0 && p.stock <= _lowStockThreshold)
        .toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    final outOfStockItems = products.where((p) => p.stock == 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final alertItems = [...outOfStockItems, ...lowStockItems];

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                'Products',
                '$totalProducts',
                Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                'Units',
                '$totalUnits',
                Icons.layers_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                'Low Stock',
                '${lowStockItems.length}',
                Icons.warning_amber_rounded,
                isWarning: lowStockItems.isNotEmpty,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                'Out of Stock',
                '${outOfStockItems.length}',
                Icons.remove_shopping_cart_outlined,
                isWarning: outOfStockItems.isNotEmpty,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Stock Alerts',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        if (alertItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('All products are sufficiently stocked.'),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: alertItems.take(12).map((product) {
                final isOutOfStock = product.stock == 0;
                return Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              isOutOfStock ? Colors.red[50] : Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isOutOfStock
                              ? Icons.error_outline
                              : Icons.warning_amber_rounded,
                          color: isOutOfStock
                              ? Colors.red[700]
                              : Colors.orange[700],
                          size: 20,
                        ),
                      ),
                      title: Text(product.name,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        isOutOfStock
                            ? 'Out of stock'
                            : '${product.stock} left (reorder <= $_lowStockThreshold)',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: () =>
                            _showAdjustStockDialog(context, ref, product),
                        child: const Text('Adjust'),
                      ),
                    ),
                    if (product != alertItems.take(12).last)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 24),
        const Text('Actions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        _buildActionTile(
          context,
          'View All Products',
          Icons.inventory_2_outlined,
          () => context.push('/products'),
        ),
        const SizedBox(height: 8),
        _buildActionTile(
          context,
          'Restock Low Stock',
          Icons.add_shopping_cart_outlined,
          () => _showBulkRestockDialog(
            context,
            ref,
            lowStockItems: [...lowStockItems, ...outOfStockItems],
          ),
        ),
      ],
    );
  }

  Future<void> _showAdjustStockDialog(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForAdjustStock(),
      title: 'Adjust Stock',
      subtitle: 'Enter PIN to adjust stock levels',
    );
    if (!allowed || !context.mounted) {
      return;
    }

    final valueController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Adjust ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current stock: ${product.stock}'),
            const SizedBox(height: 12),
            TextField(
              controller: valueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final addAmount = int.tryParse(valueController.text.trim());
              if (addAmount == null || addAmount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Enter a valid quantity to add')),
                );
                return;
              }

              final updated =
                  await ref.read(productNotifierProvider.notifier).updateStock(
                        product.id,
                        product.stock + addAmount,
                        reason: 'restock',
                        note: 'Added $addAmount units from inventory page',
                      );
              if (!context.mounted) {
                return;
              }

              if (updated) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Added $addAmount units to ${product.name}')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to add stock')),
                );
              }
            },
            child: const Text('Add'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newStock = int.tryParse(valueController.text.trim());
              if (newStock == null || newStock < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid stock value')),
                );
                return;
              }

              final updated =
                  await ref.read(productNotifierProvider.notifier).updateStock(
                        product.id,
                        newStock,
                        reason: 'stock_set',
                        note: 'Set stock to $newStock from inventory page',
                      );
              if (!context.mounted) {
                return;
              }

              if (updated) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Stock for ${product.name} set to $newStock')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to update stock')),
                );
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBulkRestockDialog(
    BuildContext context,
    WidgetRef ref, {
    required List<Product> lowStockItems,
  }) async {
    if (lowStockItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No low-stock products to restock')),
      );
      return;
    }

    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForAdjustStock(),
      title: 'Bulk Restock',
      subtitle: 'Enter PIN to restock low-stock products',
    );
    if (!allowed || !context.mounted) {
      return;
    }

    final quantityController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restock Low Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Products affected: ${lowStockItems.length}'),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Add units per product',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text.trim());
              if (quantity == null || quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid quantity')),
                );
                return;
              }

              final deltas = <String, int>{
                for (final item in lowStockItems) item.id: quantity,
              };
              final success = await ref
                  .read(productNotifierProvider.notifier)
                  .applyStockChanges(
                    deltas,
                    syncReason: 'product_bulk_restocked',
                    movementReason: 'bulk_restock',
                    note:
                        'Bulk restock of $quantity units from inventory page',
                  );

              if (!context.mounted) {
                return;
              }

              if (success) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Restocked ${lowStockItems.length} products by $quantity units',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bulk restock failed')),
                );
              }
            },
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWarning ? Colors.orange[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isWarning ? Colors.orange[100]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              color: isWarning
                  ? Colors.orange[700]
                  : Theme.of(context).colorScheme.primary,
              size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isWarning ? Colors.orange[900] : Colors.black87,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: isWarning ? Colors.orange[800] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
    );
  }
}
