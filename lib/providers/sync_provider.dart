import 'package:flutter/foundation.dart';
import '../models/sync_data.dart';
import '../services/sync_service.dart';
import '../services/chunking_service.dart';

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
  final ChunkingService _chunkingService = ChunkingService();

  SyncMode _mode = SyncMode.idle;
  SyncData? _currentSyncData;
  SyncResult? _lastSyncResult;
  String? _errorMessage;
  String? _qrData;
  int _dataSize = 0;
  SyncStrategy _selectedStrategy = SyncStrategy.merge;
  
  // Chunking support
  List<SyncChunk> _chunks = [];
  int _currentChunkIndex = 0;
  List<SyncChunk> _receivedChunks = [];
  String? _currentSessionId;

  // Getters
  SyncMode get mode => _mode;
  SyncData? get currentSyncData => _currentSyncData;
  SyncResult? get lastSyncResult => _lastSyncResult;
  String? get errorMessage => _errorMessage;
  String? get qrData => _qrData;
  int get dataSize => _dataSize;
  SyncStrategy get selectedStrategy => _selectedStrategy;
  String get dataSizeFormatted => _syncService.formatDataSize(_dataSize);
  
  // Chunking getters
  List<SyncChunk> get chunks => _chunks;
  int get currentChunkIndex => _currentChunkIndex;
  int get totalChunks => _chunks.length;
  bool get hasMultipleChunks => _chunks.length > 1;
  List<SyncChunk> get receivedChunks => _receivedChunks;
  double get scanProgress => _currentSessionId != null && _receivedChunks.isNotEmpty
      ? _chunkingService.getProgress(_receivedChunks, _receivedChunks.first.totalChunks)
      : 0.0;
  int get receivedChunkCount => _receivedChunks.length;
  int get expectedChunkCount => _receivedChunks.isNotEmpty ? _receivedChunks.first.totalChunks : 0;

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
      _chunks = [];
      _currentChunkIndex = 0;
      notifyListeners();

      // Export all data
      _currentSyncData = await _syncService.exportAllData();
      
      // Check if data is empty
      if (_currentSyncData!.isEmpty) {
        _mode = SyncMode.error;
        _errorMessage = 'No data to sync. Please add some products, sales, or other data first.';
        notifyListeners();
        return;
      }
      
      // Convert to JSON
      final jsonString = _syncService.syncDataToJson(_currentSyncData!);
      _dataSize = _syncService.calculateDataSize(_currentSyncData!);

      // Chunk the data
      _chunks = _chunkingService.chunkData(jsonString);
      
      // Set current QR data to first chunk
      if (_chunks.isNotEmpty) {
        _qrData = _chunks[0].toJsonString();
        _currentChunkIndex = 0;
      }

      _mode = SyncMode.generating;
      notifyListeners();
    } catch (e) {
      _mode = SyncMode.error;
      _errorMessage = 'Failed to export data: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Import data from scanned QR code (supports chunked data)
  Future<void> importData(String qrDataString) async {
    try {
      // Validate input
      if (qrDataString.isEmpty) {
        throw Exception('QR code data is empty');
      }

      // Try to parse as chunk
      SyncChunk? chunk;
      try {
        chunk = SyncChunk.fromJsonString(qrDataString);
      } catch (e) {
        // Not a chunk, try as regular sync data
        return await _importLegacyData(qrDataString);
      }

      // Handle chunked data
      await _handleChunk(chunk);
    } catch (e) {
      _mode = SyncMode.error;
      _errorMessage = 'Failed to import data: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Handle receiving a chunk
  Future<void> _handleChunk(SyncChunk chunk) async {
    // If this is a new session, reset received chunks
    if (_currentSessionId != chunk.sessionId) {
      _currentSessionId = chunk.sessionId;
      _receivedChunks = [];
    }

    // Add chunk if not already received
    if (!_receivedChunks.any((c) => c.chunkIndex == chunk.chunkIndex)) {
      _receivedChunks.add(chunk);
      notifyListeners();
    }

    // Check if we have all chunks
    if (_receivedChunks.length == chunk.totalChunks) {
      // All chunks received, merge and import
      _mode = SyncMode.importing;
      notifyListeners();

      try {
        final mergedData = _chunkingService.mergeChunks(_receivedChunks);
        await _importMergedData(mergedData);
      } catch (e) {
        _mode = SyncMode.error;
        _errorMessage = 'Failed to merge chunks: ${e.toString()}';
        notifyListeners();
        rethrow;
      }
    } else {
      // Still waiting for more chunks
      _mode = SyncMode.scanning;
      notifyListeners();
    }
  }

  /// Import regular (non-chunked) sync data
  Future<void> _importLegacyData(String qrDataString) async {
    _mode = SyncMode.importing;
    _errorMessage = null;
    notifyListeners();

    // Parse the scanned data
    final syncData = _syncService.jsonToSyncData(qrDataString);
    
    // Validate parsed data
    if (syncData.isEmpty) {
      _mode = SyncMode.error;
      _errorMessage = 'The scanned QR code contains no data to import.';
      notifyListeners();
      return;
    }
    
    // Import with selected strategy
    final result = await _syncService.importData(
      syncData,
      strategy: _selectedStrategy,
    );

    _lastSyncResult = result;

    if (result.success) {
      _mode = SyncMode.success;
      _receivedChunks = [];
      _currentSessionId = null;
    } else {
      _mode = SyncMode.error;
      _errorMessage = result.message;
    }
    
    notifyListeners();
  }

  /// Import merged chunk data
  Future<void> _importMergedData(String mergedData) async {
    final syncData = _syncService.jsonToSyncData(mergedData);
    
    if (syncData.isEmpty) {
      _mode = SyncMode.error;
      _errorMessage = 'The merged data contains no items to import.';
      notifyListeners();
      return;
    }
    
    final result = await _syncService.importData(
      syncData,
      strategy: _selectedStrategy,
    );

    _lastSyncResult = result;

    if (result.success) {
      _mode = SyncMode.success;
      _receivedChunks = [];
      _currentSessionId = null;
    } else {
      _mode = SyncMode.error;
      _errorMessage = result.message;
    }
      
    notifyListeners();
  }

  /// Start scanning mode
  void startScanning() {
    _mode = SyncMode.scanning;
    _errorMessage = null;
    notifyListeners();
  }

  /// Navigate to next QR chunk
  void nextChunk() {
    if (canGoNext) {
      _currentChunkIndex++;
      _qrData = _chunks[_currentChunkIndex].toJsonString();
      notifyListeners();
    }
  }

  /// Navigate to previous QR chunk
  void previousChunk() {
    if (canGoPrevious) {
      _currentChunkIndex--;
      _qrData = _chunks[_currentChunkIndex].toJsonString();
      notifyListeners();
    }
  }

  /// Can navigate to next chunk
  bool get canGoNext => _currentChunkIndex < _chunks.length - 1;

  /// Can navigate to previous chunk
  bool get canGoPrevious => _currentChunkIndex > 0;

  /// Reset to idle state
  void reset() {
    _mode = SyncMode.idle;
    _currentSyncData = null;
    _lastSyncResult = null;
    _errorMessage = null;
    _qrData = null;
    _dataSize = 0;
    _chunks = [];
    _currentChunkIndex = 0;
    _receivedChunks = [];
    _currentSessionId = null;
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
        'expenses': 0,
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
      'expenses': _currentSyncData!.expenses.length,
      'sales': _currentSyncData!.sales.length,
      'stores': _currentSyncData!.stores.length,
      'total': _currentSyncData!.totalItems,
    };
  }
}
