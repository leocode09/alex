import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/sync_provider.dart';
import '../../providers/product_provider.dart';
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
    const int maxQrDataSize = 1200; // Safe limit for QR codes with L error correction
    final bool isDataTooLarge = syncProvider.qrData != null && 
                                syncProvider.qrData!.length > maxQrDataSize && 
                                !syncProvider.hasMultipleChunks;

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
            Text(
              syncProvider.hasMultipleChunks
                  ? 'Scan all QR codes in sequence'
                  : 'Use another device to scan this code',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // Chunk Progress (if multiple chunks)
            if (syncProvider.hasMultipleChunks) ...[
              Text(
                'QR Code ${syncProvider.currentChunkIndex + 1} of ${syncProvider.totalChunks}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (syncProvider.currentChunkIndex + 1) / syncProvider.totalChunks,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 24),
            ],
            
            // QR Code or Error Message
            if (isDataTooLarge)
              _buildDataTooLargeWarning(context, syncProvider)
            else if (syncProvider.qrData != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: syncProvider.qrData!,
                  version: QrVersions.auto,
                  size: 280,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Navigation buttons for multiple chunks
            if (syncProvider.hasMultipleChunks)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: syncProvider.canGoPrevious
                        ? () => syncProvider.previousChunk()
                        : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: syncProvider.canGoNext
                        ? () => syncProvider.nextChunk()
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            
            if (syncProvider.hasMultipleChunks)
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

    // Check if we're collecting chunks
    final isCollectingChunks = syncProvider.receivedChunks.isNotEmpty;
    final progress = isCollectingChunks ? syncProvider.scanProgress : 0.0;
    final receivedCount = syncProvider.receivedChunkCount;
    final expectedCount = syncProvider.expectedChunkCount;

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
                    // Chunk collection progress
                    if (isCollectingChunks) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Collecting Chunks',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$receivedCount of $expectedCount received',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}% Complete',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'Continue scanning all QR codes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else
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
                  _buildResultRow('Expenses', result.expensesImported),
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
                onPressed: () {
                  // Refresh product providers
                  if (context.mounted) {
                    final container = riverpod.ProviderScope.containerOf(context);
                    container.invalidate(productsProvider);
                    container.invalidate(categoriesProvider);
                    container.invalidate(filteredProductsProvider);
                    container.invalidate(totalProductsCountProvider);
                  }
                  syncProvider.reset();
                },
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
          _buildStatRow('Expenses', stats['expenses']),
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

  Widget _buildDataTooLargeWarning(BuildContext context, SyncProvider syncProvider) {
    final stats = syncProvider.getSyncStats();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 2),
      ),
      child: Column(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 64,
            color: Colors.orange.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            'Data Too Large for QR Code',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your data (${syncProvider.dataSizeFormatted}) exceeds the QR code limit (2.9 KB)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡 Recommended Solutions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                if (stats['products'] > 50)
                  _buildSuggestion(
                    '1. Sync products in batches',
                    'You have ${stats['products']} products. Try syncing 30-50 at a time.',
                  ),
                if (stats['sales'] > 100)
                  _buildSuggestion(
                    '2. Sync recent sales only',
                    'You have ${stats['sales']} sales. Consider syncing last 50-100 transactions.',
                  ),
                if (stats['products'] <= 50 && stats['sales'] <= 100)
                  _buildSuggestion(
                    '1. Reduce data volume',
                    'Remove unnecessary items or sync categories separately.',
                  ),
                _buildSuggestion(
                  stats['products'] > 50 || stats['sales'] > 100 ? '3. Use selective sync' : '2. Use selective sync',
                  'Sync only essential data like products and categories first.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => syncProvider.reset(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade300),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showDataReductionDialog(context, syncProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('View Data'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestion(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
        ],
      ),
    );
  }

  void _showDataReductionDialog(BuildContext context, SyncProvider syncProvider) {
    final stats = syncProvider.getSyncStats();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Data Breakdown'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Size: ${syncProvider.dataSizeFormatted}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildDataRow('Products', stats['products']),
              _buildDataRow('Categories', stats['categories']),
              _buildDataRow('Customers', stats['customers']),
              _buildDataRow('Employees', stats['employees']),
              _buildDataRow('Expenses', stats['expenses']),
              _buildDataRow('Sales', stats['sales']),
              _buildDataRow('Stores', stats['stores']),
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Tip',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'For best results, keep your sync data under 2.9 KB. Consider syncing in multiple sessions or reducing the number of items.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              syncProvider.reset();
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScannedCode(
    BuildContext context,
    SyncProvider syncProvider,
    String code,
  ) async {
    try {
      // Validate the scanned data
      if (code.isEmpty) {
        throw Exception('QR code is empty');
      }

      // Attempt to parse to validate format
      jsonDecode(code);

      // Import the data
      await syncProvider.importData(code);
      
      // If still in scanning mode (collecting chunks), restart scanner
      if (mounted && syncProvider.isScanning) {
        _isProcessingScan = false;
        await _scannerController?.start();
      }
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
        // Reset to scanning state and restart scanner
        syncProvider.startScanning();
        await _scannerController?.start();
      }
    } finally {
      if (mounted) {
        _isProcessingScan = false;
      }
    }
  }
}
