import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';
import '../../../models/product.dart';
import '../../../providers/receipt_provider.dart';
import '../../../providers/printer_provider.dart';
import '../../../providers/sale_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../repositories/sale_repository.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';
import '../../../services/wifi_direct_sync_service.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
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

                      // Customer Info
                      if (_sale.customerId != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Customer: ${_sale.customerId}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),

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
              final name = nameController.text.isEmpty
                  ? item.productName
                  : nameController.text;

              final updatedItems = List<SaleItem>.from(_sale.items);
              updatedItems[index] = SaleItem(
                productId: item.productId,
                productName: name,
                quantity: quantity,
                price: price,
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
        onItemAdded: (Product product, int quantity) async {
          // Add the product to the receipt
          final newItem = SaleItem(
            productId: product.id,
            productName: product.name,
            quantity: quantity,
            price: product.price,
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

    final updatedSale = Sale(
      id: _sale.id,
      items: updatedItems,
      total: newTotal,
      paymentMethod: _sale.paymentMethod,
      customerId: _sale.customerId,
      employeeId: _sale.employeeId,
      createdAt: _sale.createdAt,
    );

    await ref.read(saleRepositoryProvider).updateSale(updatedSale);
    await WifiDirectSyncService().triggerSync(reason: 'receipt_items_updated');

    // Refresh providers
    ref.invalidate(salesProvider);
    ref.invalidate(todaysRevenueProvider);
    ref.invalidate(totalRevenueProvider);

    if (mounted) {
      setState(() {
        _sale = updatedSale;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Items updated successfully')),
      );
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

                final updatedSale = Sale(
                  id: _sale.id,
                  items: _sale.items,
                  total: _sale.total,
                  paymentMethod: paymentMethod,
                  customerId: customerController.text.isEmpty
                      ? null
                      : customerController.text,
                  employeeId: _sale.employeeId,
                  createdAt: newDateTime,
                );

                await ref.read(saleRepositoryProvider).updateSale(updatedSale);
                await WifiDirectSyncService()
                    .triggerSync(reason: 'receipt_details_updated');

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
    final printerService = ref.read(printerServiceProvider);
    try {
      await printerService.printReceipt(_sale, settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printing...')),
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

class _AddItemDialog extends ConsumerStatefulWidget {
  final Function(Product product, int quantity) onItemAdded;

  const _AddItemDialog({required this.onItemAdded});

  @override
  ConsumerState<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends ConsumerState<_AddItemDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  String _searchQuery = '';
  Product? _selectedProduct;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
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
                  final filtered = _searchQuery.isEmpty
                      ? products
                      : products.where((p) =>
                          p.name.toLowerCase().contains(_searchQuery) ||
                          (p.barcode?.toLowerCase().contains(_searchQuery) ?? false) ||
                          (p.sku?.toLowerCase().contains(_searchQuery) ?? false)
                        ).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
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
                                final allowed = await PinProtection.requirePinIfNeeded(
                                  context,
                                  isRequired: () => PinService().isPinRequiredForAddProduct(),
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
                                context.push('/products/add?name=${Uri.encodeComponent(_searchQuery)}');
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
                      final product = filtered[index];
                      final isSelected = _selectedProduct?.id == product.id;

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
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('\$${product.price.toStringAsFixed(2)}'),
                            Text(
                              'Stock: ${product.stock}',
                              style: TextStyle(
                                color: product.stock < 10
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
                            _selectedProduct = product;
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
            if (_selectedProduct != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final quantity = int.tryParse(_quantityController.text) ?? 1;
                        if (quantity <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid quantity'),
                            ),
                          );
                          return;
                        }
                        
                        if (_selectedProduct!.stock < quantity) {
                          final proceed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Low Stock Warning'),
                              content: Text(
                                'Only ${_selectedProduct!.stock} units available. '
                                'Do you want to continue?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Continue'),
                                ),
                              ],
                            ),
                          );
                          
                          if (proceed != true) return;
                        }

                        await widget.onItemAdded(_selectedProduct!, quantity);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${_selectedProduct!.name} added to receipt',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text(
                        'Add to Receipt (\$${(_selectedProduct!.price * (int.tryParse(_quantityController.text) ?? 1)).toStringAsFixed(2)})',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
