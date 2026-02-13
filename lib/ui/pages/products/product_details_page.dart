import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/inventory_movement.dart';
import '../../../models/product.dart';
import '../../../models/sale.dart';
import '../../../providers/inventory_movement_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/sale_provider.dart';
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
    final salesAsync = ref.watch(salesProvider);
    final movementsAsync =
        ref.watch(productInventoryMovementsProvider(productId));
    final dateFormatter = DateFormat('MMM d, yyyy - h:mm a');

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
                if (!context.mounted) {
                  return;
                }
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
                  isRequired: () =>
                      PinService().isPinRequiredForDeleteProduct(),
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

          final salesEntries = salesAsync.maybeWhen(
            data: (sales) => _buildProductSaleEntries(sales, product.id),
            orElse: () => <_ProductSaleEntry>[],
          );
          final totalSoldUnits = salesEntries.fold<int>(
              0, (sum, entry) => sum + entry.item.quantity);
          final totalSalesCount = salesEntries.length;
          final totalSoldRevenue = salesEntries.fold<double>(
            0.0,
            (sum, entry) => sum + entry.item.subtotal,
          );
          final lastSoldAt = salesEntries.isNotEmpty
              ? salesEntries.first.sale.createdAt
              : null;

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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showAddStockDialog(context, ref, product),
                        icon: const Icon(Icons.add_box_outlined, size: 18),
                        label: const Text('Add Stock'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showSetStockDialog(context, ref, product),
                        icon: const Icon(Icons.tune_outlined, size: 18),
                        label: const Text('Set Stock'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showRecordVarianceDialog(context, ref, product),
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: const Text('Record Variance'),
                  ),
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
                if (product.costPrice != null && product.price > 0)
                  _buildDetailRow('Margin',
                      '${((product.price - product.costPrice!) / product.price * 100).toStringAsFixed(1)}%'),
                _buildDetailRow('Description', product.description ?? '-'),
                _buildDetailRow('Created',
                    dateFormatter.format(product.createdAt.toLocal())),
                _buildDetailRow('Updated',
                    dateFormatter.format(product.updatedAt.toLocal())),
                const SizedBox(height: 32),

                const Text('Performance',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.9,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildMetricCard(
                      context,
                      title: 'Sold Units',
                      value: '$totalSoldUnits',
                      icon: Icons.sell_outlined,
                      color: Colors.indigo,
                    ),
                    _buildMetricCard(
                      context,
                      title: 'Sales Count',
                      value: '$totalSalesCount',
                      icon: Icons.receipt_long_outlined,
                      color: Colors.teal,
                    ),
                    _buildMetricCard(
                      context,
                      title: 'Revenue',
                      value: '\$${totalSoldRevenue.toStringAsFixed(2)}',
                      icon: Icons.attach_money_outlined,
                      color: Colors.green,
                    ),
                    _buildMetricCard(
                      context,
                      title: 'Last Sold',
                      value: lastSoldAt == null
                          ? 'Never'
                          : DateFormat('MMM d').format(lastSoldAt.toLocal()),
                      icon: Icons.schedule_outlined,
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                const Text('Sales History',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                salesAsync.when(
                  data: (sales) {
                    final productSales =
                        _buildProductSaleEntries(sales, product.id);
                    if (productSales.isEmpty) {
                      return _buildEmptyStateCard(
                        icon: Icons.receipt_long_outlined,
                        text: 'No sales recorded for this product yet.',
                      );
                    }
                    return _buildSalesHistoryList(productSales, dateFormatter);
                  },
                  loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (err, _) => _buildEmptyStateCard(
                    icon: Icons.error_outline,
                    text: 'Failed to load sales history: $err',
                  ),
                ),
                const SizedBox(height: 32),

                const Text('Inventory Movements',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                movementsAsync.when(
                  data: (movements) {
                    if (movements.isEmpty) {
                      return _buildEmptyStateCard(
                        icon: Icons.swap_vert_outlined,
                        text:
                            'No inventory movement logs yet. New stock changes will appear here.',
                      );
                    }
                    return _buildInventoryMovementsList(
                      movements: movements,
                      dateFormatter: dateFormatter,
                    );
                  },
                  loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (err, _) => _buildEmptyStateCard(
                    icon: Icons.error_outline,
                    text: 'Failed to load inventory history: $err',
                  ),
                ),
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

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        color: Colors.grey[50],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesHistoryList(
    List<_ProductSaleEntry> entries,
    DateFormat dateFormatter,
  ) {
    final visibleEntries = entries.take(20).toList();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: visibleEntries.asMap().entries.map((entry) {
          final index = entry.key;
          final saleEntry = entry.value;
          final sale = saleEntry.sale;
          final item = saleEntry.item;
          final subtitle =
              '${item.quantity} units - \$${item.price.toStringAsFixed(2)} each\n${dateFormatter.format(sale.createdAt.toLocal())} - Receipt #${_shortId(sale.id)}';

          return Column(
            children: [
              ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue[50],
                  child: Icon(Icons.sell_outlined,
                      size: 16, color: Colors.blue[700]),
                ),
                title: Text(
                  item.productName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle:
                    Text(subtitle, style: TextStyle(color: Colors.grey[600])),
                trailing: Text(
                  '\$${item.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              if (index != visibleEntries.length - 1)
                const Divider(height: 1, indent: 12, endIndent: 12),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInventoryMovementsList({
    required List<InventoryMovement> movements,
    required DateFormat dateFormatter,
  }) {
    final visibleMovements = movements.take(30).toList();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: visibleMovements.asMap().entries.map((entry) {
          final index = entry.key;
          final movement = entry.value;
          final isIn = movement.delta > 0;
          final isOut = movement.delta < 0;
          final arrowIcon = isIn
              ? Icons.arrow_upward
              : isOut
                  ? Icons.arrow_downward
                  : Icons.horizontal_rule;
          final arrowColor = isIn
              ? Colors.green
              : isOut
                  ? Colors.red
                  : Colors.grey;
          final deltaText =
              movement.delta > 0 ? '+${movement.delta}' : '${movement.delta}';
          final reasonText = _formatMovementReason(movement.reason);
          final subtitle =
              '$reasonText - ${dateFormatter.format(movement.createdAt.toLocal())}\nStock: ${movement.stockBefore} -> ${movement.stockAfter}';

          return Column(
            children: [
              ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: arrowColor.withValues(alpha: 0.12),
                  child: Icon(arrowIcon, size: 16, color: arrowColor),
                ),
                title: Text(
                  movement.delta == 0 ? 'No stock change' : '$deltaText units',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle:
                    Text(subtitle, style: TextStyle(color: Colors.grey[600])),
                trailing: movement.referenceId == null
                    ? null
                    : Text(
                        '#${_shortId(movement.referenceId!)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
              ),
              if (index != visibleMovements.length - 1)
                const Divider(height: 1, indent: 12, endIndent: 12),
            ],
          );
        }).toList(),
      ),
    );
  }

  List<_ProductSaleEntry> _buildProductSaleEntries(
    List<Sale> sales,
    String productId,
  ) {
    final entries = <_ProductSaleEntry>[];
    for (final sale in sales) {
      for (final item in sale.items) {
        if (item.productId == productId) {
          entries.add(_ProductSaleEntry(sale: sale, item: item));
        }
      }
    }
    entries.sort((a, b) => b.sale.createdAt.compareTo(a.sale.createdAt));
    return entries;
  }

  String _formatMovementReason(String reason) {
    if (InventoryMovement.isVarianceReason(reason)) {
      final code =
          reason.substring(InventoryMovement.varianceReasonPrefix.length);
      switch (code) {
        case 'count':
          return 'Cycle Count';
        case 'damage':
          return 'Variance - Damage';
        case 'theft':
          return 'Variance - Theft';
        case 'expired':
          return 'Variance - Expired';
        case 'found':
          return 'Variance - Found Stock';
        case 'correction':
          return 'Variance - Correction';
        case 'other':
          return 'Variance - Other';
        default:
          return 'Variance - ${_titleCaseWords(code)}';
      }
    }

    switch (reason) {
      case 'sale':
        return 'Sale';
      case 'sale_receipt_edit':
        return 'Receipt Edit';
      case 'sale_delete':
        return 'Receipt Deleted';
      case 'restock':
        return 'Restock';
      case 'bulk_restock':
        return 'Bulk Restock';
      case 'stock_set':
        return 'Manual Stock Set';
      case 'stock_adjustment':
        return 'Stock Adjustment';
      default:
        return _titleCaseWords(reason);
    }
  }

  String _titleCaseWords(String value) {
    return value
        .split('_')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _shortId(String id) {
    return id.length <= 6 ? id : id.substring(0, 6);
  }

  Future<void> _showAddStockDialog(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForAdjustStock(),
      title: 'Add Stock',
      subtitle: 'Enter PIN to add stock',
    );
    if (!allowed || !context.mounted) {
      return;
    }

    final quantityController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add Stock - ${product.name}'),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantity to add',
            border: OutlineInputBorder(),
          ),
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

              final updated =
                  await ref.read(productNotifierProvider.notifier).updateStock(
                        product.id,
                        product.stock + quantity,
                        reason: 'restock',
                        note: 'Manual restock from product details',
                      );

              if (!context.mounted) {
                return;
              }

              if (updated) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added $quantity units to ${product.name}'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to add stock')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSetStockDialog(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForAdjustStock(),
      title: 'Set Stock',
      subtitle: 'Enter PIN to set stock quantity',
    );
    if (!allowed || !context.mounted) {
      return;
    }

    final stockController = TextEditingController(text: '${product.stock}');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Set Stock - ${product.name}'),
        content: TextField(
          controller: stockController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'New stock quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newStock = int.tryParse(stockController.text.trim());
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
                        note: 'Manual stock set from product details',
                      );

              if (!context.mounted) {
                return;
              }

              if (updated) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${product.name} stock set to $newStock'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to set stock')),
                );
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecordVarianceDialog(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForAdjustStock(),
      title: 'Record Variance',
      subtitle: 'Enter PIN to record stock variance',
    );
    if (!allowed || !context.mounted) {
      return;
    }

    final countedStockController =
        TextEditingController(text: product.stock.toString());
    final noteController = TextEditingController();
    final reasons = <MapEntry<String, String>>[
      const MapEntry('count', 'Cycle Count'),
      const MapEntry('damage', 'Damage'),
      const MapEntry('theft', 'Theft'),
      const MapEntry('expired', 'Expired'),
      const MapEntry('found', 'Found Stock'),
      const MapEntry('correction', 'Correction'),
      const MapEntry('other', 'Other'),
    ];
    var selectedReason = reasons.first.key;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Record Variance - ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Expected stock: ${product.stock}'),
              const SizedBox(height: 12),
              TextField(
                controller: countedStockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Counted stock',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                items: reasons
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setDialogState(() => selectedReason = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
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
                final countedStock =
                    int.tryParse(countedStockController.text.trim());
                if (countedStock == null || countedStock < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid stock count')),
                  );
                  return;
                }

                final delta = countedStock - product.stock;
                final success = await ref
                    .read(productNotifierProvider.notifier)
                    .recordProductVariance(
                      product.id,
                      countedStock: countedStock,
                      reasonCode: selectedReason,
                      referenceId:
                          'variance_${DateTime.now().millisecondsSinceEpoch}',
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                    );

                if (!context.mounted) {
                  return;
                }

                if (success) {
                  Navigator.pop(dialogContext);
                  final sign = delta > 0 ? '+' : '';
                  final suffix = delta == 0
                      ? 'No stock change'
                      : 'Stock change: $sign$delta';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Variance recorded. $suffix')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to record variance')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
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
                final deleted = await ref
                    .read(productNotifierProvider.notifier)
                    .deleteProduct(productId);
                if (!deleted) {
                  throw Exception('Delete failed');
                }

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

class _ProductSaleEntry {
  final Sale sale;
  final SaleItem item;

  _ProductSaleEntry({
    required this.sale,
    required this.item,
  });
}
