import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/product_provider.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';

class ProductDetailsPage extends ConsumerWidget {
  final String productId;

  const ProductDetailsPage({
    super.key,
    required this.productId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productProvider(productId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final pinService = PinService();
              final requirePin = await pinService.isPinRequiredForEditProduct();
              
              if (requirePin) {
                final verified = await PinProtection.requirePin(context);
                if (verified && context.mounted) {
                  context.push('/product/edit/$productId');
                }
              } else {
                context.push('/product/edit/$productId');
              }
            },
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 20),
                    SizedBox(width: 8),
                    Text('Duplicate'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print, size: 20),
                    SizedBox(width: 8),
                    Text('Print Label'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'delete') {
                final verified = await PinProtection.requirePinIfNeeded(
                  context,
                  isRequired: () => PinService().isPinRequiredForDeleteProduct(),
                  title: 'Delete Product',
                  subtitle: 'Enter PIN to delete a product',
                );
                if (verified && context.mounted) {
                  _confirmDelete(context, ref);
                }
              }
            },
          ),
        ],
      ),
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return const Center(child: Text('Product not found'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.inventory_2_outlined,
                            size: 40, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        product.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      if (product.category != null &&
                          product.category!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            product.category!,
                            style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        context,
                        'Stock',
                        '${product.stock}',
                        product.stock < 10
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey[200]),
                    Expanded(
                      child: _buildStatItem(
                        context,
                        'Price',
                        '\$${product.price.toInt()}',
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey[200]),
                    Expanded(
                      child: _buildStatItem(
                        context,
                        'Value',
                        '\$${(product.price * product.stock).toInt()}',
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Details
                const Text('Information',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                _buildDetailRow('Barcode', product.barcode ?? '-'),
                _buildDetailRow('Supplier', product.supplier ?? '-'),
                _buildDetailRow(
                    'Cost Price',
                    product.costPrice != null
                        ? '\$${product.costPrice!.toInt()}'
                        : '-'),
                if (product.costPrice != null)
                  _buildDetailRow('Margin',
                      '${((product.price - product.costPrice!) / product.price * 100).toStringAsFixed(1)}%'),
                _buildDetailRow('Description', product.description ?? '-'),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context, String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text(
            'Are you sure you want to delete this product? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              try {
                final repository = ref.read(productRepositoryProvider);
                await repository.deleteProduct(productId);

                // Invalidate providers to refresh lists
                ref.invalidate(productsProvider);
                ref.invalidate(filteredProductsProvider);
                ref.invalidate(totalProductsCountProvider);
                ref.invalidate(totalInventoryValueProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Product deleted successfully')),
                  );
                  context.pop(); // Go back to list
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting product: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
