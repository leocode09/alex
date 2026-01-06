import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/sync_provider.dart';
import '../../services/sync_service.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({Key? key}) : super(key: key);

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  MobileScannerController? _scannerController;
  bool _isProcessingScan = false;

  @override
  void dispose() {
    _scannerController?.dispose();
    _scannerController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SyncProvider(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sync Data'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Consumer<SyncProvider>(
          builder: (context, syncProvider, _) {
            if (syncProvider.isIdle) {
              return _buildInitialView(context, syncProvider);
            } else if (syncProvider.isGenerating) {
              return _buildQRCodeView(context, syncProvider);
            } else if (syncProvider.isScanning) {
              return _buildScannerView(context, syncProvider);
            } else if (syncProvider.isSuccess) {
              return _buildSuccessView(context, syncProvider);
            } else if (syncProvider.hasError) {
              return _buildErrorView(context, syncProvider);
            } else if (syncProvider.isBusy) {
              return _buildLoadingView(context, syncProvider);
            }
            
            return _buildInitialView(context, syncProvider);
          },
        ),
      ),
    );
  }

  Widget _buildInitialView(BuildContext context, SyncProvider syncProvider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sync,
              size: 100,
              color: Colors.blue.shade300,
            ),
            const SizedBox(height: 24),
            const Text(
              'Sync Your Data',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Synchronize all your products, sales, and other data between devices using QR codes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),
            
            // Sync Strategy Selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sync Strategy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStrategyOption(
                    context,
                    syncProvider,
                    SyncStrategy.merge,
                    'Merge (Recommended)',
                    'Keep most recent data',
                    Icons.merge,
                  ),
                  _buildStrategyOption(
                    context,
                    syncProvider,
                    SyncStrategy.append,
                    'Append Only',
                    'Add new items only',
                    Icons.add_circle_outline,
                  ),
                  _buildStrategyOption(
                    context,
                    syncProvider,
                    SyncStrategy.replace,
                    'Replace All',
                    'Replace all data (⚠️ destructive)',
                    Icons.swap_horiz,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Generate QR Code Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _exportData(context, syncProvider),
                icon: const Icon(Icons.qr_code, size: 28),
                label: const Text(
                  'Generate QR Code',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Scan QR Code Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => _startScanning(context, syncProvider),
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: const Text(
                  'Scan QR Code',
                  style: TextStyle(fontSize: 18),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyOption(
    BuildContext context,
    SyncProvider syncProvider,
    SyncStrategy strategy,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = syncProvider.selectedStrategy == strategy;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => syncProvider.setStrategy(strategy),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.blue : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.blue : Colors.black,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Colors.blue,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRCodeView(BuildContext context, SyncProvider syncProvider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Scan this QR Code',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use another device to scan this code',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // QR Code
            if (syncProvider.qrData != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: syncProvider.qrData!,
                  version: QrVersions.auto,
                  size: 300,
                  backgroundColor: Colors.white,
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Stats
            _buildStatsCard(context, syncProvider),
            
            const SizedBox(height: 24),
            
            // Back Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => syncProvider.reset(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerView(BuildContext context, SyncProvider syncProvider) {
    if (_scannerController == null) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            if (_isProcessingScan) return;
            
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null && !_isProcessingScan) {
                _isProcessingScan = true;
                _handleScannedCode(context, syncProvider, barcode.rawValue!);
                break;
              }
            }
          },
        ),
        
        // Overlay
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
          ),
          child: Column(
            children: [
              AppBar(
                title: const Text('Scan QR Code'),
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => syncProvider.reset(),
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text(
                      'Position the QR code within the frame',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _scannerController?.toggleTorch(),
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Toggle Flash'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(BuildContext context, SyncProvider syncProvider) {
    final result = syncProvider.lastSyncResult!;
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 100,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            const Text(
              'Sync Successful!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Successfully imported ${result.totalImported} items',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            
            // Import Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildResultRow('Products', result.productsImported),
                  _buildResultRow('Categories', result.categoriesImported),
                  _buildResultRow('Customers', result.customersImported),
                  _buildResultRow('Employees', result.employeesImported),
                  _buildResultRow('Sales', result.salesImported),
                  _buildResultRow('Stores', result.storesImported),
                  const Divider(height: 24),
                  _buildResultRow('Total', result.totalImported, isTotal: true),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => syncProvider.reset(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, SyncProvider syncProvider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 100,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            const Text(
              'Sync Failed',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                syncProvider.errorMessage ?? 'An unknown error occurred',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => syncProvider.reset(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(BuildContext context, SyncProvider syncProvider) {
    String message = 'Processing...';
    if (syncProvider.isExporting) {
      message = 'Exporting data...';
    } else if (syncProvider.isImporting) {
      message = 'Importing data...';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, SyncProvider syncProvider) {
    final stats = syncProvider.getSyncStats();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data to Sync',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatRow('Products', stats['products']),
          _buildStatRow('Categories', stats['categories']),
          _buildStatRow('Customers', stats['customers']),
          _buildStatRow('Employees', stats['employees']),
          _buildStatRow('Sales', stats['sales']),
          _buildStatRow('Stores', stats['stores']),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Items:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '${stats['total']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Size:',
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
              Text(
                syncProvider.dataSizeFormatted,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '$count',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, int count, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Colors.blue : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, SyncProvider syncProvider) async {
    try {
      await syncProvider.exportData();
      
      // Check if QR data size is reasonable
      if (syncProvider.dataSize > 4000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Warning: Data size is large. QR code may be hard to scan. Consider syncing in smaller batches.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _startScanning(BuildContext context, SyncProvider syncProvider) {
    _isProcessingScan = false;
    syncProvider.startScanning();
  }

  Future<void> _handleScannedCode(
    BuildContext context,
    SyncProvider syncProvider,
    String code,
  ) async {
    // Stop the scanner
    await _scannerController?.stop();

    try {
      // Validate the scanned data
      if (code.isEmpty) {
        throw Exception('QR code is empty');
      }

      // Attempt to parse to validate format
      jsonDecode(code);

      // Import the data
      await syncProvider.importData(code);
    } catch (e) {
      _isProcessingScan = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import data: ${e.toString().contains('FormatException') ? 'Invalid QR code format' : e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        // Reset to scanning state
        syncProvider.startScanning();
      }
    } finally {
      if (mounted) {
        _isProcessingScan = false;
      }
    }
  }
}
