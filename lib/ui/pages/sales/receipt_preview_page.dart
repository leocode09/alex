import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';
import '../../../providers/receipt_provider.dart';
import '../../../providers/printer_provider.dart';
import '../../../providers/sale_provider.dart';
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
                            _sale.cashReceived?.toStringAsFixed(0) ??
                                _sale.total.toStringAsFixed(0),
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

  void _editItem(BuildContext context, int index, SaleItem item) {
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

  void _removeItem(BuildContext context, int index) {
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

  void _showEditSaleDialog(BuildContext context) {
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

  void _showSettingsDialog(
      BuildContext context, ReceiptSettings currentSettings) {
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
