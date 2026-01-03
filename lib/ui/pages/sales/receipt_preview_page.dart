import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';
import '../../../providers/receipt_provider.dart';
import '../../../providers/printer_provider.dart';
import 'receipts_page.dart'; // For PrinterDialog

class ReceiptPreviewPage extends ConsumerStatefulWidget {
  final Sale sale;

  const ReceiptPreviewPage({super.key, required this.sale});

  @override
  ConsumerState<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends ConsumerState<ReceiptPreviewPage> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(receiptSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => Navigator.pop(context),
          ),
          IconButton(
            icon: const Icon(Icons.store),
            onPressed: () => _showSettingsDialog(context, settings),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context, settings),
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
                            DateFormat('d MMM y HH:mm').format(widget.sale.createdAt),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '#${widget.sale.id.substring(0, 6)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(thickness: 1, height: 24, color: Colors.black),

                      // Items
                      ...widget.sale.items.map((item) => Padding(
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
                            widget.sale.total.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(widget.sale.paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            widget.sale.total.toStringAsFixed(0),
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
      await printerService.printReceipt(widget.sale, settings);
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
