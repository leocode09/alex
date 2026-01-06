import 'package:flutter/foundation.dart';
import '../models/sync_data.dart';
import '../services/sync_service.dart';

enum SyncMode {
  idle,
  exporting,
  importing,
  scanning,
  generating,
  error,
  success,
}

class SyncProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();

  SyncMode _mode = SyncMode.idle;
  SyncData? _currentSyncData;
  SyncResult? _lastSyncResult;
  String? _errorMessage;
  String? _qrData;
  int _dataSize = 0;
  SyncStrategy _selectedStrategy = SyncStrategy.merge;

  // Getters
  SyncMode get mode => _mode;
  SyncData? get currentSyncData => _currentSyncData;
  SyncResult? get lastSyncResult => _lastSyncResult;
  String? get errorMessage => _errorMessage;
  String? get qrData => _qrData;
  int get dataSize => _dataSize;
  SyncStrategy get selectedStrategy => _selectedStrategy;
  String get dataSizeFormatted => _syncService.formatDataSize(_dataSize);

  bool get isIdle => _mode == SyncMode.idle;
  bool get isExporting => _mode == SyncMode.exporting;
  bool get isImporting => _mode == SyncMode.importing;
  bool get isScanning => _mode == SyncMode.scanning;
  bool get isGenerating => _mode == SyncMode.generating;
  bool get hasError => _mode == SyncMode.error;
  bool get isSuccess => _mode == SyncMode.success;
  bool get isBusy => isExporting || isImporting || isScanning || isGenerating;

  void setStrategy(SyncStrategy strategy) {
    _selectedStrategy = strategy;
    notifyListeners();
  }

  /// Export all data and prepare for QR code generation
  Future<void> exportData() async {
    try {
      _mode = SyncMode.exporting;
      _errorMessage = null;
      _qrData = null;
      notifyListeners();

      // Export all data
      _currentSyncData = await _syncService.exportAllData();
      
      // Convert to JSON
      final jsonString = _syncService.syncDataToJson(_currentSyncData!);
      _qrData = jsonString;
      _dataSize = _syncService.calculateDataSize(_currentSyncData!);

      _mode = SyncMode.generating;
      notifyListeners();
    } catch (e) {
      _mode = SyncMode.error;
      _errorMessage = 'Failed to export data: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Import data from scanned QR code
  Future<void> importData(String qrDataString) async {
    try {
      _mode = SyncMode.importing;
      _errorMessage = null;
      notifyListeners();

      // Parse the scanned data
      final syncData = _syncService.jsonToSyncData(qrDataString);
      
      // Import with selected strategy
      final result = await _syncService.importData(
        syncData,
        strategy: _selectedStrategy,
      );

      _lastSyncResult = result;

      if (result.success) {
        _mode = SyncMode.success;
      } else {
        _mode = SyncMode.error;
        _errorMessage = result.message;
      }
      
      notifyListeners();
    } catch (e) {
      _mode = SyncMode.error;
      _errorMessage = 'Failed to import data: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Start scanning mode
  void startScanning() {
    _mode = SyncMode.scanning;
    _errorMessage = null;
    notifyListeners();
  }

  /// Reset to idle state
  void reset() {
    _mode = SyncMode.idle;
    _currentSyncData = null;
    _lastSyncResult = null;
    _errorMessage = null;
    _qrData = null;
    _dataSize = 0;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    if (_mode == SyncMode.error) {
      _mode = SyncMode.idle;
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Get sync strategy description
  String getStrategyDescription(SyncStrategy strategy) {
    switch (strategy) {
      case SyncStrategy.replace:
        return 'Replace all existing data with incoming data. This will delete all current data.';
      case SyncStrategy.merge:
        return 'Merge data intelligently. Keeps newer items based on timestamps. Recommended.';
      case SyncStrategy.append:
        return 'Only add new items. Existing items will not be modified or deleted.';
    }
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStats() {
    if (_currentSyncData == null) {
      return {
        'products': 0,
        'categories': 0,
        'customers': 0,
        'employees': 0,
        'sales': 0,
        'stores': 0,
        'total': 0,
      };
    }

    return {
      'products': _currentSyncData!.products.length,
      'categories': _currentSyncData!.categories.length,
      'customers': _currentSyncData!.customers.length,
      'employees': _currentSyncData!.employees.length,
      'sales': _currentSyncData!.sales.length,
      'stores': _currentSyncData!.stores.length,
      'total': _currentSyncData!.totalItems,
    };
  }
}
