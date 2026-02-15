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
                  'Recommended Solutions:',
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
                  stats['products'] > 50 || stats['sales'] > 100
                      ? '3. Use selective sync'
                      : '2. Use selective sync',
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
                  onPressed: () =>
                      _showDataReductionDialog(context, syncProvider),
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

  void _showDataReductionDialog(
      BuildContext context, SyncProvider syncProvider) {
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
                        Icon(Icons.info_outline,
                            size: 20, color: Colors.blue.shade700),
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
            content: Text(
                'Failed to import data: ${e.toString().contains('FormatException') ? 'Invalid QR code format' : e.toString()}'),
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
