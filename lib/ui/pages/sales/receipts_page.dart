import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../providers/sale_provider.dart';
import '../../../providers/printer_provider.dart';
import 'receipt_preview_page.dart';

class ReceiptsTab extends ConsumerStatefulWidget {
  const ReceiptsTab({super.key});

  @override
  ConsumerState<ReceiptsTab> createState() => _ReceiptsTabState();
}

class _ReceiptsTabState extends ConsumerState<ReceiptsTab> {
  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showPrinterDialog(context),
                icon: const Icon(Icons.print),
                label: const Text('Connect Printer'),
              ),
            ],
          ),
        ),
        Expanded(
          child: salesAsync.when(
            data: (sales) {
              if (sales.isEmpty) {
                return const Center(child: Text('No receipts found'));
              }
              return ListView.builder(
                itemCount: sales.length,
                itemBuilder: (context, index) {
                  final sale = sales[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReceiptPreviewPage(sale: sale),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '\$${sale.total.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  DateFormat('MMM d, HH:mm').format(sale.createdAt),
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${sale.items.length} items • ${sale.paymentMethod}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  void _showPrinterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PrinterDialog(),
    );
  }
}

class PrinterDialog extends ConsumerStatefulWidget {
  const PrinterDialog({super.key});

  @override
  ConsumerState<PrinterDialog> createState() => _PrinterDialogState();
}

class _PrinterDialogState extends ConsumerState<PrinterDialog> {
  bool _isConnecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    try {
      setState(() => _error = null);
      await ref.read(printerServiceProvider).startScan();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  void dispose() {
    // Use read to avoid watching in dispose
    ref.read(printerServiceProvider).stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final printerService = ref.watch(printerServiceProvider);
    
    return AlertDialog(
      title: const Text('Select Printer'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_isConnecting)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: StreamBuilder<BluetoothAdapterState>(
                  stream: printerService.adapterState,
                  initialData: BluetoothAdapterState.unknown,
                  builder: (context, stateSnapshot) {
                    if (stateSnapshot.data != BluetoothAdapterState.on) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text('Bluetooth is ${stateSnapshot.data?.name ?? "unknown"}'),
                            if (stateSnapshot.data == BluetoothAdapterState.off)
                              TextButton(
                                onPressed: _startScan,
                                child: const Text('Turn On & Scan'),
                              ),
                          ],
                        ),
                      );
                    }

                    return StreamBuilder<List<ScanResult>>(
                      stream: printerService.scanResults,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final results = snapshot.data!
                            .where((r) => r.device.platformName.isNotEmpty)
                            .toList();
                            
                        if (results.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('No devices found'),
                                TextButton(
                                  onPressed: _startScan,
                                  child: const Text('Retry Scan'),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final result = results[index];
                            final device = result.device;
                            return ListTile(
                              leading: const Icon(Icons.print),
                              title: Text(device.platformName),
                              subtitle: Text(device.remoteId.toString()),
                              onTap: () async {
                                setState(() => _isConnecting = true);
                                try {
                                  await printerService.connect(device);
                                  if (mounted) Navigator.pop(context);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Connected to ${device.platformName}')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(() {
                                      _isConnecting = false;
                                      _error = 'Connection failed: $e';
                                    });
                                  }
                                }
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
