import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/product.dart';
import '../../../providers/product_provider.dart';
import '../../themes/app_theme.dart';

class ProductDetailsPage extends ConsumerWidget {
  final String productId;

  const ProductDetailsPage({
    super.key,
    required this.productId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productProvider(productId));

    return productAsync.when(
      data: (product) {
        if (product == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Product Details'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Product not found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID: $productId',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/products'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Products'),
                  ),
                ],
              ),
            ),
          );
        }
          return _buildProductDetails(context, product, ref);
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Product Details'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          title: const Text('Product Details'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading product',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(productProvider(productId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetails(BuildContext context, Product product, WidgetRef ref) {
    // Calculate stock value based on selling price
    final stockValue = product.price * product.stock;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/product/edit/${product.id}'),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Duplicate'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print),
                    SizedBox(width: 8),
                    Text('Print Label'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Header Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    if (product.category != null && product.category!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.amberLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          product.category!,
                          style: const TextStyle(
                            color: AppTheme.amberDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.inventory_2_outlined,
                    label: 'In Stock',
                    value: '${product.stock}',
                    color: product.stock > 50 
                        ? AppTheme.greenPantone 
                        : product.stock > 20 
                            ? AppTheme.amberSae 
                            : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.attach_money,
                    label: 'Stock Value',
                    value: '${(stockValue / 1000).toStringAsFixed(1)}K',
                    color: AppTheme.greenPantone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pricing Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_offer, color: AppTheme.amberSae, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Pricing Information',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      context, 
                      'Selling Price', 
                      '${product.price.toStringAsFixed(0)} RWF', 
                      AppTheme.greenPantone,
                    ),
                    if (product.costPrice != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        context, 
                        'Cost Price', 
                        '${product.costPrice!.toStringAsFixed(0)} RWF', 
                        Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        context, 
                        'Profit per Unit', 
                        '${(product.price - product.costPrice!).toStringAsFixed(0)} RWF', 
                        AppTheme.greenPantone,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        context, 
                        'Profit Margin', 
                        '${((product.price - product.costPrice!) / product.price * 100).toStringAsFixed(1)}%', 
                        AppTheme.greenPantone,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Product Information Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.amberSae, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Product Information',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (product.barcode != null && product.barcode!.isNotEmpty) ...[
                      _buildInfoRow(context, 'Barcode', product.barcode!, null),
                      const SizedBox(height: 12),
                    ],
                    if (product.supplier != null && product.supplier!.isNotEmpty) ...[
                      _buildInfoRow(context, 'Supplier', product.supplier!, null),
                      const SizedBox(height: 12),
                    ],
                    _buildInfoRow(context, 'Product ID', product.id, null),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context, 
                      'Created', 
                      _formatDate(product.createdAt), 
                      null,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context, 
                      'Last Updated', 
                      _formatDate(product.updatedAt), 
                      null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRestockDialog(context, product, ref),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Restock'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: AppTheme.greenPantone,
                      side: const BorderSide(color: AppTheme.greenPantone),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/product/edit/${product.id}'),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Product'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Product'),
                      content: Text('Are you sure you want to delete ${product.name}? This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            final router = GoRouter.of(context);
                            
                            navigator.pop();
                            
                            try {
                              final repo = ref.read(productRepositoryProvider);
                              await repo.deleteProduct(product.id);
                              ref.invalidate(productsProvider);
                              
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(content: Text('Product deleted')),
                              );
                              router.go('/products');
                            } catch (e) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error deleting product: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestockDialog(BuildContext context, Product product, WidgetRef ref) {
    final quantityController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_shopping_cart, color: AppTheme.greenPantone),
            const SizedBox(width: 8),
            const Text('Restock Product'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.amberLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Current Stock:', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text(
                    '${product.stock} units',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.amberDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Quantity to Add',
                hintText: 'Enter quantity',
                prefixIcon: const Icon(Icons.add_circle_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _performRestock(context, product, quantityController.text, ref);
                }
              },
            ),
            const SizedBox(height: 12),
            // Quick action buttons
            Wrap(
              spacing: 8,
              children: [
                _buildQuickAddButton(context, quantityController, 10),
                _buildQuickAddButton(context, quantityController, 20),
                _buildQuickAddButton(context, quantityController, 50),
                _buildQuickAddButton(context, quantityController, 100),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => _performRestock(context, product, quantityController.text, ref),
            icon: const Icon(Icons.check),
            label: const Text('Restock'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.greenPantone,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButton(BuildContext context, TextEditingController controller, int quantity) {
    return ActionChip(
      label: Text('+$quantity'),
      onPressed: () {
        controller.text = quantity.toString();
      },
      backgroundColor: AppTheme.greenLight,
      labelStyle: const TextStyle(
        color: AppTheme.greenDark,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  void _performRestock(BuildContext context, Product product, String quantityText, WidgetRef ref) async {
    final quantity = int.tryParse(quantityText);
    
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Capture navigators before async operations
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Close dialog
    navigator.pop();

    // Show loading
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Restocking...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      // Increase stock
      final repo = ref.read(productRepositoryProvider);
      await repo.increaseStock(product.id, quantity);
      
      // Refresh product data
      ref.invalidate(productProvider(product.id));
      ref.invalidate(productsProvider);

      // Show success
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Added $quantity units. New stock: ${product.stock + quantity}'),
              ),
            ],
          ),
          backgroundColor: AppTheme.greenPantone,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error restocking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, Color? valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}

