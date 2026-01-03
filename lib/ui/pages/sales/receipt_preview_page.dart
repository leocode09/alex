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
        title: const Text('Receipt', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (settings.addressLine1.isNotEmpty)
                        Text(
                          settings.addressLine1,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      if (settings.addressLine2.isNotEmpty)
                        Text(
                          settings.addressLine2,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      if (settings.phone.isNotEmpty)
                        Text(
                          settings.phone,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      const Divider(thickness: 1, height: 24, color: Colors.black),

                      // Customer Info
                      if (_sale.customerId != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Customer: ${_sale.customerId}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),

                      // Items
                      ..._sale.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${item.quantity}x ${item.price.toStringAsFixed(2)}'),
                                Text(
                                  item.subtotal.toStringAsFixed(2),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),
                      const Divider(thickness: 1, height: 24, color: Colors.black),

                      // Delivery (Placeholder)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('0', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(thickness: 1, height: 24, color: Colors.black),

                      // Totals
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                            _sale.total.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_sale.paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            _sale.total.toStringAsFixed(0),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Change due', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            (0.0).toStringAsFixed(2), // Placeholder
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      const SnackBar(content: Text('WhatsApp sharing not implemented yet')),
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

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
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

  void _showEditSaleDialog(BuildContext context) {
    final customerController = TextEditingController(text: _sale.customerId ?? '');
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
                  decoration: const InputDecoration(labelText: 'Payment Method'),
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
                  customerId: customerController.text.isEmpty ? null : customerController.text,
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

  void _showSettingsDialog(BuildContext context, ReceiptSettings currentSettings) {
    final shopNameController = TextEditingController(text: currentSettings.shopName);
    final address1Controller = TextEditingController(text: currentSettings.addressLine1);
    final address2Controller = TextEditingController(text: currentSettings.addressLine2);
    final phoneController = TextEditingController(text: currentSettings.phone);
    final footerController = TextEditingController(text: currentSettings.footerMessage);

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
