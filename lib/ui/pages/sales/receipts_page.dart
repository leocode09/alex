import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../models/sale.dart';
import '../../../providers/sale_provider.dart';
import '../../../providers/printer_provider.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';
import 'receipt_preview_page.dart';

class ReceiptsTab extends ConsumerStatefulWidget {
  const ReceiptsTab({super.key});

  @override
  ConsumerState<ReceiptsTab> createState() => _ReceiptsTabState();
}

class _ReceiptsTabState extends ConsumerState<ReceiptsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search receipts, IDs, items, totals, dates',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.trim().isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: salesAsync.when(
            data: (sales) {
              if (sales.isEmpty) {
                return const Center(child: Text('No receipts found'));
              }
              final filteredSales = _filterSales(sales, _searchQuery);
              if (filteredSales.isEmpty) {
                return Center(
                  child: Text(
                    'No receipts match "${_searchQuery.trim()}"',
                  ),
                );
              }
              return ListView.builder(
                itemCount: filteredSales.length,
                itemBuilder: (context, index) {
                  final sale = filteredSales[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: InkWell(
                      onTap: () async {
                        final allowed = await PinProtection.requirePinIfNeeded(
                          context,
                          isRequired: () =>
                              PinService().isPinRequiredForViewSalesHistory(),
                          title: 'Sales History',
                          subtitle: 'Enter PIN to view receipt',
                        );
                        if (!allowed) {
                          return;
                        }
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ReceiptPreviewPage(sale: sale),
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                Text(
                                  DateFormat('MMM d, HH:mm')
                                      .format(sale.createdAt),
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${sale.items.length} items - ${sale.paymentMethod}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PIN Reference: #${_shortReceiptRef(sale.id)}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
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

  List<Sale> _filterSales(List<Sale> sales, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return sales;
    }

    final tokens = trimmed
        .split(RegExp(r'\s+'))
        .map(_normalize)
        .where((token) => token.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return sales;
    }

    return sales
        .where((sale) => _matchesSaleQuery(sale, tokens))
        .toList(growable: false);
  }

  bool _matchesSaleQuery(Sale sale, List<String> queryTokens) {
    final searchable = _buildSearchableText(sale);
    return queryTokens.every(searchable.contains);
  }

  String _buildSearchableText(Sale sale) {
    final itemNames = sale.items.map((item) => item.productName).join(' ');
    final itemIds = sale.items.map((item) => item.productId).join(' ');
    final totalQuantity =
        sale.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final dateA = DateFormat('MMM d, HH:mm').format(sale.createdAt);
    final dateB = DateFormat('MMM d, yyyy HH:mm').format(sale.createdAt);
    final dateC = DateFormat('yyyy-MM-dd').format(sale.createdAt);
    final dateD = DateFormat('dd/MM/yyyy').format(sale.createdAt);
    final dateE = DateFormat('HH:mm').format(sale.createdAt);
    final fullRef = sale.id.toUpperCase();
    final shortRef = _shortReceiptRef(sale.id);

    final source = [
      sale.id,
      fullRef,
      shortRef,
      '#$shortRef',
      sale.paymentMethod,
      sale.total.toStringAsFixed(2),
      sale.total.toStringAsFixed(0),
      '\$${sale.total.toStringAsFixed(2)}',
      sale.customerId ?? '',
      sale.employeeId,
      itemNames,
      itemIds,
      sale.items.length.toString(),
      totalQuantity.toString(),
      dateA,
      dateB,
      dateC,
      dateD,
      dateE,
      sale.cashReceived?.toStringAsFixed(2) ?? '',
      sale.change?.toStringAsFixed(2) ?? '',
    ].join(' ');

    return _normalize(source);
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _shortReceiptRef(String saleId) {
    if (saleId.length <= 6) {
      return saleId.toUpperCase();
    }
    return saleId.substring(0, 6).toUpperCase();
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
                            const Icon(Icons.bluetooth_disabled,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                                'Bluetooth is ${stateSnapshot.data?.name ?? "unknown"}'),
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
                          return const Center(
                              child: CircularProgressIndicator());
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
                                      SnackBar(
                                          content: Text(
                                              'Connected to ${device.platformName}')),
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
