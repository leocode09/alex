import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';
import '../../../models/product.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/receipt_provider.dart';
import '../../../providers/printer_provider.dart';
import '../../../providers/sale_provider.dart';
import '../../../providers/inventory_movement_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../helpers/license_gate.dart';
import '../../../helpers/pin_protection.dart';
import '../../../models/license_policy.dart';
import '../../../services/bonus_rule_service.dart';
import '../../../services/pin_service.dart';
import '../../../services/receipt_print_service.dart';
import '../../../services/data_sync_triggers.dart';
import 'receipts_page.dart'; // For PrinterDialog

class ReceiptPreviewPage extends ConsumerStatefulWidget {
  final Sale sale;

  const ReceiptPreviewPage({super.key, required this.sale});

  @override
  ConsumerState<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends ConsumerState<ReceiptPreviewPage> {
  late Sale _sale;

  @override
  void initState() {
    super.initState();
    _sale = widget.sale;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(receiptSettingsProvider);
    final bonusRuleEnabled = ref.watch(bonusRuleProvider).enabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Receipt',
            onPressed: () => _deleteReceipt(context),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Sale Details',
            onPressed: () => _showEditSaleDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.store),
            tooltip: 'Shop Settings',
            onPressed: () => _showSettingsDialog(context, settings),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: () => _printReceipt(settings),
          ),
        ],
      ),
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                  width: 350, // Approximate width of a receipt
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Text(
                        settings.shopName,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (settings.addressLine1.isNotEmpty)
                        Text(
                          settings.addressLine1,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      if (settings.addressLine2.isNotEmpty)
                        Text(
                          settings.addressLine2,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      if (settings.phone.isNotEmpty)
                        Text(
                          settings.phone,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 24),

                      // Date & ID
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('d MMM y HH:mm').format(_sale.createdAt),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '#${_sale.id.substring(0, 6)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(
                          thickness: 1, height: 24, color: Colors.black),

                      // Seller (device name stored as employeeId at checkout)
                      if (_sale.employeeId.trim().isNotEmpty &&
                          _sale.employeeId != 'default-employee')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Seller: ${_sale.employeeId}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),

                      // Customer Info
                      if (_sale.customerId != null) _buildCustomerBlock(),

                      // Items
                      ..._sale.items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return InkWell(
                          onTap: () => _editItem(context, index, item),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                              '${item.quantity}x ${item.price.toStringAsFixed(2)}'),
                                          Text(
                                            item.subtotal.toStringAsFixed(2),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      if (item.profit != null)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            'Profit: ${item.profit!.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: item.profit! >= 0
                                                  ? Colors.green[700]
                                                  : Colors.red[700],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _removeItem(context, index),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      // Add item button
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddItemDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 36),
                          ),
                        ),
                      ),
                      const Divider(
                          thickness: 1, height: 24, color: Colors.black),

                      // Totals
                      _buildLineRow(
                        'Total products',
                        _sale.totalProducts.toString(),
                      ),
                      const SizedBox(height: 4),
                      if (_sale.creditApplied > 0) ...[
                        _buildLineRow('Subtotal',
                            (_sale.total + _sale.creditApplied)
                                .toStringAsFixed(2)),
                        const SizedBox(height: 4),
                        _buildLineRow('Credit applied',
                            '-${_sale.creditApplied.toStringAsFixed(2)}'),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                            _sale.total.toStringAsFixed(2),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Builder(builder: (_) {
                        final profit = _computeSaleProfit(_sale);
                        if (profit == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Profit',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                profit.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: profit >= 0
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_sale.paymentMethod,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            _sale.cashReceived?.toStringAsFixed(2) ??
                                _sale.total.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (_sale.paymentMethod == 'Cash' &&
                          _sale.cashReceived != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                _sale.change != null && _sale.change! > 0
                                    ? 'Change due'
                                    : 'Amount due',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                              _sale.change != null && _sale.change! > 0
                                  ? _sale.change!.toStringAsFixed(2)
                                  : (_sale.total - _sale.cashReceived!)
                                      .toStringAsFixed(2),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                      if (!_sale.isPaidInFull) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Paid',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              _sale.amountPaid.toStringAsFixed(2),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Amount Due',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFC62828))),
                            Text(
                              _sale.amountDue.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC62828),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (bonusRuleEnabled &&
                          _sale.customerId != null &&
                          (_sale.bonusEarned > 0 ||
                              _sale.customerCreditBalanceAfter > 0 ||
                              _sale.customerTotalSpentAfter > 0)) ...[
                        const SizedBox(height: 16),
                        const Divider(
                            thickness: 1, height: 8, color: Colors.black),
                        const SizedBox(height: 8),
                        const Text('Customer Rewards',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 6),
                        if (_sale.bonusEarned > 0)
                          _buildLineRow('Bonus earned',
                              '+${_sale.bonusEarned.toStringAsFixed(2)}'),
                        if (_sale.customerCreditBalanceAfter > 0 ||
                            _sale.bonusEarned > 0 ||
                            _sale.creditApplied > 0)
                          _buildLineRow(
                              'Credit balance',
                              _sale.customerCreditBalanceAfter
                                  .toStringAsFixed(2)),
                        if (_sale.customerTotalSpentAfter > 0)
                          _buildLineRow(
                              'Total spending',
                              _sale.customerTotalSpentAfter
                                  .toStringAsFixed(2)),
                      ],
                      const SizedBox(height: 40),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 150,
                          height: 1,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        settings.footerMessage,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.settings,
                  label: 'Settings',
                  onTap: () => _showSettingsDialog(context, settings),
                ),
                _buildActionButton(
                  icon: Icons.print,
                  label: 'Print',
                  onTap: () => _printReceipt(settings),
                ),
                _buildActionButton(
                  icon: Icons.chat, // WhatsApp icon placeholder
                  label: 'WhatsApp',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('WhatsApp sharing not implemented yet')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildCustomerBlock() {
    final rawId = _sale.customerId!;
    final looksLikeId = rawId.startsWith('cust_');
    if (!looksLikeId) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Customer: $rawId',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      );
    }
    final async = ref.watch(customerByIdProvider(rawId));
    final displayName = async.asData?.value?.name ??
        _sale.customerNameSnapshot ??
        rawId;
    final phone = async.asData?.value?.phone;
    final email = async.asData?.value?.email;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer: $displayName',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          if ((phone ?? '').isNotEmpty)
            Text('Phone: $phone', style: const TextStyle(fontSize: 12)),
          if ((email ?? '').isNotEmpty)
            Text('Email: $email', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  double? _computeSaleProfit(Sale sale) {
    double totalProfit = 0;
    bool hasCost = false;
    for (final item in sale.items) {
      final p = item.profit;
      if (p != null) {
        totalProfit += p;
        hasCost = true;
      }
    }
    return hasCost ? totalProfit : null;
  }

  Map<String, int> _buildItemQuantities(List<SaleItem> items) {
    final quantities = <String, int>{};
    for (final item in items) {
      quantities[item.productId] =
          (quantities[item.productId] ?? 0) + item.baseUnitsSold;
    }
    return quantities;
  }

  Map<String, int> _buildStockDeltas({
    required Map<String, int> oldQuantities,
    required Map<String, int> newQuantities,
  }) {
    final stockDeltas = <String, int>{};
    final productIds = <String>{...oldQuantities.keys, ...newQuantities.keys};
    for (final productId in productIds) {
      final oldQuantity = oldQuantities[productId] ?? 0;
      final newQuantity = newQuantities[productId] ?? 0;
      final delta = oldQuantity - newQuantity;
      if (delta != 0) {
        stockDeltas[productId] = delta;
      }
    }
    return stockDeltas;
  }

  Map<String, int> _invertStockDeltas(Map<String, int> deltas) {
    return {
      for (final entry in deltas.entries) entry.key: -entry.value,
    };
  }

  Future<void> _editItem(BuildContext context, int index, SaleItem item) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForEditReceipt(),
      title: 'Edit Receipt',
      subtitle: 'Enter PIN to edit receipt items',
    );
    if (!allowed) {
      return;
    }
    if (!mounted) {
      return;
    }

    final quantityController =
        TextEditingController(text: item.quantity.toString());
    final priceController =
        TextEditingController(text: item.price.toStringAsFixed(2));
    final nameController = TextEditingController(text: item.productName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Product Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity =
                  int.tryParse(quantityController.text) ?? item.quantity;
              final price = double.tryParse(priceController.text) ?? item.price;
              if (quantity <= 0 || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Quantity and price must be greater than 0')),
                );
                return;
              }

              final name = nameController.text.isEmpty
                  ? item.productName
                  : nameController.text;

              final updatedItems = List<SaleItem>.from(_sale.items);
              updatedItems[index] = SaleItem(
                productId: item.productId,
                productName: name,
                quantity: quantity,
                price: price,
                packageId: item.packageId,
                packageName: item.packageName,
                unitsPerPackage: item.unitsPerPackage,
                costPrice: item.costPrice,
              );

              await _updateSaleItems(updatedItems);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeItem(BuildContext context, int index) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForEditReceipt(),
      title: 'Edit Receipt',
      subtitle: 'Enter PIN to remove items',
    );
    if (!allowed) {
      return;
    }
    if (!mounted) {
      return;
    }

    if (_sale.items.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove the last item')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content:
            Text('Remove ${_sale.items[index].productName} from this receipt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final updatedItems = List<SaleItem>.from(_sale.items)
                ..removeAt(index);
              await _updateSaleItems(updatedItems);
              if (mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForEditReceipt(),
      title: 'Edit Receipt',
      subtitle: 'Enter PIN to add items',
    );
    if (!allowed) {
      return;
    }
    if (!mounted) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        onItemAdded:
            (Product product, ProductPackage? package, int quantity) async {
          final isSinglePkg = package?.id == productPackageSingleItemId;
          final unitsPerPackage = package?.unitsPerPackage ?? 1;
          final price = (package != null && !isSinglePkg)
              ? sellingPriceForPackage(unitPrice: product.price, pkg: package)
              : product.price;
          final costPrice = (package != null &&
                  !isSinglePkg &&
                  package.packageCostPrice != null)
              ? package.packageCostPrice! / package.unitsPerPackage
              : product.costPrice;
          final newItem = SaleItem(
            productId: product.id,
            productName: (package != null && !isSinglePkg)
                ? '${product.name} (${package.name})'
                : product.name,
            quantity: quantity,
            price: price,
            packageId: (package != null && !isSinglePkg) ? package.id : null,
            packageName:
                (package != null && !isSinglePkg) ? package.name : null,
            unitsPerPackage:
                (package != null && !isSinglePkg) ? unitsPerPackage : null,
            costPrice: costPrice,
          );

          final updatedItems = List<SaleItem>.from(_sale.items)..add(newItem);
          await _updateSaleItems(updatedItems);
        },
      ),
    );
  }

  Future<void> _updateSaleItems(List<SaleItem> updatedItems) async {
    final newTotal = updatedItems.fold<double>(
      0.0,
      (sum, item) => sum + item.subtotal,
    );
    final cashReceived =
        _sale.paymentMethod == 'Cash' ? _sale.cashReceived : null;
    final change = cashReceived != null && cashReceived >= newTotal
        ? cashReceived - newTotal
        : null;

    final updatedSale = _sale.copyWith(
      items: updatedItems,
      total: newTotal,
      cashReceived: cashReceived,
      change: change,
    );

    final productRepo = ref.read(productRepositoryProvider);
    final saleRepo = ref.read(saleRepositoryProvider);
    final oldQuantities = _buildItemQuantities(_sale.items);
    final newQuantities = _buildItemQuantities(updatedItems);
    final stockDeltas = _buildStockDeltas(
      oldQuantities: oldQuantities,
      newQuantities: newQuantities,
    );
    bool stockApplied = false;
    bool bucketsReconciled = false;

    try {
      if (stockDeltas.isNotEmpty) {
        await productRepo.applyStockChanges(
          stockDeltas,
          reason: 'sale_receipt_edit',
          referenceId: _sale.id,
          note: 'Stock adjusted from receipt item update',
          absorbInventoryDrift: false,
        );
        stockApplied = true;
        await productRepo.reconcilePackageBucketsAfterSale(
          deduct: updatedItems,
          reverseFirst: _sale.items,
        );
        bucketsReconciled = true;
      }

      final updated = await saleRepo.updateSale(updatedSale);
      if (!updated) {
        throw Exception('Failed to update receipt.');
      }

      await DataSyncTriggers.trigger(reason: 'receipt_items_updated');
    } catch (e) {
      Object error = e;
      if (stockApplied) {
        try {
          await productRepo.applyStockChanges(
            _invertStockDeltas(stockDeltas),
            reason: 'rollback',
            referenceId: _sale.id,
            note: 'Rollback failed receipt stock update',
            recordMovement: false,
            absorbInventoryDrift: false,
          );
          if (bucketsReconciled) {
            await productRepo.reconcilePackageBucketsAfterSale(
              reverseFirst: updatedItems,
              deduct: _sale.items,
            );
          }
        } catch (rollbackError) {
          error = Exception('$e Stock rollback failed: $rollbackError');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
      return;
    }

    // Refresh providers
    ref.invalidate(productsProvider);
    ref.invalidate(lowStockProductsProvider);
    ref.invalidate(totalInventoryValueProvider);
    ref.invalidate(salesProvider);
    ref.invalidate(todaysRevenueProvider);
    ref.invalidate(totalRevenueProvider);
    ref.invalidate(inventoryMovementsProvider);
    ref.invalidate(inventoryVariancesProvider);
    ref.invalidate(inventoryVarianceStatsProvider);
    ref.invalidate(productInventoryMovementsProvider);
    ref.invalidate(productInventoryVariancesProvider);

    if (mounted) {
      setState(() {
        _sale = updatedSale;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Items updated successfully')),
      );
    }
  }

  Future<void> _deleteReceipt(BuildContext context) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForDeleteReceipt(),
      title: 'Delete Receipt',
      subtitle: 'Enter PIN to delete this receipt',
    );
    if (!allowed) {
      return;
    }
    if (!mounted) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: const Text(
          'Delete this receipt permanently? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final productRepo = ref.read(productRepositoryProvider);
    final saleRepo = ref.read(saleRepositoryProvider);
    final quantitiesToRestore = _buildItemQuantities(_sale.items);
    final restockChanges = <String, int>{};
    int missingProducts = 0;
    bool stockApplied = false;

    try {
      final products = await productRepo.getAllProducts();
      final existingProductIds = products.map((p) => p.id).toSet();

      for (final entry in quantitiesToRestore.entries) {
        if (existingProductIds.contains(entry.key)) {
          restockChanges[entry.key] = entry.value;
        } else {
          missingProducts += 1;
        }
      }

      if (restockChanges.isNotEmpty) {
        await productRepo.applyStockChanges(
          restockChanges,
          reason: 'sale_delete',
          referenceId: _sale.id,
          note: 'Stock restored from deleted receipt',
          absorbInventoryDrift: false,
        );
        await productRepo.reconcilePackageBucketsAfterSale(
          reverseFirst: _sale.items,
          deduct: const [],
        );
        stockApplied = true;
      }

      final deleted = await saleRepo.deleteSale(_sale.id);
      if (!deleted) {
        throw Exception('Failed to delete receipt.');
      }

      await DataSyncTriggers.trigger(reason: 'receipt_deleted');

      ref.invalidate(productsProvider);
      ref.invalidate(lowStockProductsProvider);
      ref.invalidate(totalInventoryValueProvider);
      ref.invalidate(salesProvider);
      ref.invalidate(todaysSalesProvider);
      ref.invalidate(todaysSalesCountProvider);
      ref.invalidate(todaysRevenueProvider);
      ref.invalidate(totalRevenueProvider);
      ref.invalidate(totalSalesCountProvider);
      ref.invalidate(weeklySalesProvider);
      ref.invalidate(weeklyRevenueProvider);
      ref.invalidate(yesterdaysSalesProvider);
      ref.invalidate(yesterdaysSalesCountProvider);
      ref.invalidate(yesterdaysRevenueProvider);
      ref.invalidate(lastWeekRevenueProvider);
      ref.invalidate(inventoryMovementsProvider);
      ref.invalidate(inventoryVariancesProvider);
      ref.invalidate(inventoryVarianceStatsProvider);
      ref.invalidate(productInventoryMovementsProvider);
      ref.invalidate(productInventoryVariancesProvider);

      if (!mounted) {
        return;
      }

      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            missingProducts > 0
                ? 'Receipt deleted. $missingProducts removed product(s) were not restocked.'
                : 'Receipt deleted successfully.',
          ),
        ),
      );
    } catch (e) {
      if (stockApplied && restockChanges.isNotEmpty) {
        try {
          await productRepo.applyStockChanges(
            _invertStockDeltas(restockChanges),
            reason: 'rollback',
            referenceId: _sale.id,
            note: 'Rollback failed receipt delete stock restore',
            recordMovement: false,
            absorbInventoryDrift: false,
          );
          await productRepo.reconcilePackageBucketsAfterSale(
            deduct: _sale.items,
            reverseFirst: const [],
          );
        } catch (_) {}
      }

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error deleting receipt: $e')),
        );
      }
    }
  }

  Future<void> _showEditSaleDialog(BuildContext context) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForEditReceipt(),
      title: 'Edit Receipt',
      subtitle: 'Enter PIN to edit receipt details',
    );
    if (!allowed) {
      return;
    }
    if (!mounted) {
      return;
    }

    final customerController =
        TextEditingController(text: _sale.customerId ?? '');
    String paymentMethod = _sale.paymentMethod;
    DateTime selectedDate = _sale.createdAt;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(_sale.createdAt);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Sale Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: customerController,
                  decoration: const InputDecoration(labelText: 'Customer Name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration:
                      const InputDecoration(labelText: 'Payment Method'),
                  items: ['Cash', 'Card', 'Mobile Money', 'Other']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) => setState(() => paymentMethod = val!),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date & Time'),
                  subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(
                    DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    ),
                  )),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (time != null) {
                        setState(() {
                          selectedDate = date;
                          selectedTime = time;
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final updatedSale = _sale.copyWith(
                  paymentMethod: paymentMethod,
                  customerId: customerController.text.isEmpty
                      ? null
                      : customerController.text,
                  cashReceived:
                      paymentMethod == 'Cash' ? _sale.cashReceived : null,
                  change: paymentMethod == 'Cash' ? _sale.change : null,
                  createdAt: newDateTime,
                );

                await ref.read(saleRepositoryProvider).updateSale(updatedSale);
                await DataSyncTriggers.trigger(
                  reason: 'receipt_details_updated',
                );

                // Refresh providers
                ref.invalidate(salesProvider);
                ref.invalidate(todaysSalesCountProvider);
                ref.invalidate(todaysRevenueProvider);

                if (mounted) {
                  this.setState(() {
                    _sale = updatedSale;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sale updated successfully')),
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

  Future<void> _showSettingsDialog(
      BuildContext context, ReceiptSettings currentSettings) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForReceiptSettings(),
      title: 'Receipt Settings',
      subtitle: 'Enter PIN to update receipt settings',
    );
    if (!allowed) {
      return;
    }
    if (!mounted) {
      return;
    }

    final shopNameController =
        TextEditingController(text: currentSettings.shopName);
    final address1Controller =
        TextEditingController(text: currentSettings.addressLine1);
    final address2Controller =
        TextEditingController(text: currentSettings.addressLine2);
    final phoneController = TextEditingController(text: currentSettings.phone);
    final footerController =
        TextEditingController(text: currentSettings.footerMessage);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: shopNameController,
                decoration: const InputDecoration(labelText: 'Shop Name'),
              ),
              TextField(
                controller: address1Controller,
                decoration: const InputDecoration(labelText: 'Address Line 1'),
              ),
              TextField(
                controller: address2Controller,
                decoration: const InputDecoration(labelText: 'Address Line 2'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: footerController,
                decoration: const InputDecoration(labelText: 'Footer Message'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(receiptSettingsProvider.notifier).updateSettings(
                    currentSettings.copyWith(
                      shopName: shopNameController.text,
                      addressLine1: address1Controller.text,
                      addressLine2: address2Controller.text,
                      phone: phoneController.text,
                      footerMessage: footerController.text,
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt(ReceiptSettings settings) async {
    if (!await LicenseGate.ensure(context, FeatureKey.printing)) {
      return;
    }
    final printerService = ref.read(printerServiceProvider);
    final receiptPrintService = ReceiptPrintService();

    try {
      final printCount = await receiptPrintService.getPrintCount(_sale.id);
      final nextPrintNumber = printCount + 1;
      if (!mounted) {
        return;
      }

      if (printCount >= 1) {
        final allowed = await PinProtection.requirePinIfNeeded(
          context,
          isRequired: () async => true,
          title: 'Reprint Receipt',
          subtitle: 'Enter PIN to reprint this receipt',
        );
        if (!mounted) {
          return;
        }
        if (!allowed) {
          return;
        }
      }

      await printerService.printReceipt(
        _sale,
        settings,
        printNumber: nextPrintNumber,
      );
      await receiptPrintService.markPrinted(
        _sale.id,
        printNumber: nextPrintNumber,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Printing... (${receiptPrintService.buildPrintLabel(nextPrintNumber)})',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print Error: $e')),
        );
        showDialog(
          context: context,
          builder: (context) => const PrinterDialog(),
        );
      }
    }
  }
}

class _AddEntry {
  final Product product;
  final ProductPackage? package;
  const _AddEntry(this.product, [this.package]);

  String get key => '${product.id}_${package?.id ?? ''}';
}

class _AddItemDialog extends ConsumerStatefulWidget {
  final Function(Product product, ProductPackage? package, int quantity)
      onItemAdded;

  const _AddItemDialog({required this.onItemAdded});

  @override
  ConsumerState<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends ConsumerState<_AddItemDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  String _searchQuery = '';
  _AddEntry? _selectedEntry;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  List<_AddEntry> _buildEntries(List<Product> products) {
    final entries = <_AddEntry>[];
    for (final product in products) {
      if (product.packages.isEmpty) {
        entries.add(_AddEntry(product));
      } else {
        if (product.price > 0) {
          entries.add(_AddEntry(
            product,
            ProductPackage(
              id: productPackageSingleItemId,
              name: 'Single',
              unitsPerPackage: 1,
            ),
          ));
        }
        for (final pkg in product.packages) {
          entries.add(_AddEntry(product, pkg));
        }
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Item to Receipt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),

            // Product list
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  final filteredProducts = _searchQuery.isEmpty
                      ? products
                      : products
                          .where((p) =>
                              p.name.toLowerCase().contains(_searchQuery) ||
                              (p.barcode
                                      ?.toLowerCase()
                                      .contains(_searchQuery) ??
                                  false) ||
                              (p.sku?.toLowerCase().contains(_searchQuery) ??
                                  false))
                          .toList();
                  final filtered = _buildEntries(filteredProducts);

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No products available'
                                : 'No products found for "$_searchQuery"',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final allowed =
                                    await PinProtection.requirePinIfNeeded(
                                  context,
                                  isRequired: () =>
                                      PinService().isPinRequiredForAddProduct(),
                                  title: 'Add Product',
                                  subtitle: 'Enter PIN to add a product',
                                );
                                if (!allowed) {
                                  return;
                                }
                                if (!mounted) {
                                  return;
                                }
                                Navigator.pop(context);
                                context.push(
                                    '/products/add?name=${Uri.encodeComponent(_searchQuery)}');
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Create Product'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      final product = entry.product;
                      final pkg = entry.package;
                      final isSingleEntry =
                          pkg?.id == productPackageSingleItemId;
                      final isPackageEntry = pkg != null && !isSingleEntry;
                      final isSelected = _selectedEntry?.key == entry.key;
                      final displayPrice = isPackageEntry
                          ? sellingPriceForPackage(
                              unitPrice: product.price, pkg: pkg)
                          : product.price;
                      final stockCount = isPackageEntry
                          ? pkg.packageCount
                          : isSingleEntry
                              ? product.looseStock
                              : product.stock;
                      final displayName = pkg != null
                          ? '${product.name} (${pkg.name})'
                          : product.name;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.grey[600],
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('\$${displayPrice.toStringAsFixed(2)}'),
                            Text(
                              'Stock: $stockCount',
                              style: TextStyle(
                                color: stockCount < 10
                                    ? Colors.red[700]
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedEntry = entry;
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text('Error loading products: $err'),
                ),
              ),
            ),

            // Quantity and Add button
            if (_selectedEntry != null) ...[
              const Divider(height: 24),
              Builder(builder: (context) {
                final selectedEntry = _selectedEntry!;
                final product = selectedEntry.product;
                final pkg = selectedEntry.package;
                final isSingleEntry =
                    pkg?.id == productPackageSingleItemId;
                final isPackageEntry = pkg != null && !isSingleEntry;
                final unitsPerPackage = pkg?.unitsPerPackage ?? 1;
                final unitPrice = isPackageEntry
                    ? sellingPriceForPackage(
                        unitPrice: product.price, pkg: pkg)
                    : product.price;
                final qty = int.tryParse(_quantityController.text) ?? 1;
                final displayName = pkg != null
                    ? '${product.name} (${pkg.name})'
                    : product.name;

                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantityController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText:
                              isPackageEntry ? 'Packs' : 'Quantity',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final quantity =
                              int.tryParse(_quantityController.text) ?? 1;
                          if (quantity <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid quantity'),
                              ),
                            );
                            return;
                          }

                          final baseUnitsNeeded = quantity * unitsPerPackage;
                          if (product.stock < baseUnitsNeeded) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Only ${product.stock} units available.',
                                ),
                              ),
                            );
                            return;
                          }

                          await widget.onItemAdded(product, pkg, quantity);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '$displayName added to receipt',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: Text(
                          'Add to Receipt (\$${(unitPrice * qty).toStringAsFixed(2)})',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
