import 'dart:async';
import 'dart:convert';
import '../models/product.dart';
import '../models/sale.dart';
import 'product_service.dart';
import 'sale_service.dart';
import 'bluetooth_service.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

class SyncData {
  final List<Product> products;
  final List<Sale> sales;
  final DateTime timestamp;

  SyncData({
    required this.products,
    required this.sales,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'products': products.map((p) => p.toMap()).toList(),
      'sales': sales.map((s) => s.toMap()).toList(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SyncData.fromMap(Map<String, dynamic> map) {
    return SyncData(
      products: (map['products'] as List)
          .map((p) => Product.fromMap(p as Map<String, dynamic>))
          .toList(),
      sales: (map['sales'] as List)
          .map((s) => Sale.fromMap(s as Map<String, dynamic>))
          .toList(),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  String toJson() => json.encode(toMap());
  
  factory SyncData.fromJson(String source) =>
      SyncData.fromMap(json.decode(source) as Map<String, dynamic>);
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final BluetoothService _bluetoothService = BluetoothService();
  final ProductService _productService = ProductService();
  final SaleService _saleService = SaleService();

  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();
  final StreamController<String> _syncMessageController =
      StreamController<String>.broadcast();

  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;
  Stream<String> get syncMessage => _syncMessageController.stream;

  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;

  void _updateStatus(SyncStatus status, [String? message]) {
    _currentStatus = status;
    _syncStatusController.add(status);
    if (message != null) {
      _syncMessageController.add(message);
    }
  }

  /// Initialize sync service and listen for incoming data
  void initialize() {
    _bluetoothService.receivedData.listen((data) {
      _handleReceivedData(data);
    });
  }

  /// Send all local data to connected device
  Future<bool> sendFullSync() async {
    if (!_bluetoothService.isConnected) {
      _updateStatus(SyncStatus.error, 'No device connected');
      return false;
    }

    try {
      _updateStatus(SyncStatus.syncing, 'Preparing data...');

      // Get all local data
      final products = await _productService.getProducts();
      final sales = await _saleService.getSales();

      final syncData = SyncData(
        products: products,
        sales: sales,
        timestamp: DateTime.now(),
      );

      _updateStatus(SyncStatus.syncing, 'Sending data...');

      // Create sync package
      final package = {
        'type': 'full_sync',
        'data': syncData.toMap(),
      };

      // Send data
      bool success = await _bluetoothService.sendData(json.encode(package));

      if (success) {
        _updateStatus(SyncStatus.success, 'Data sent successfully');
        return true;
      } else {
        _updateStatus(SyncStatus.error, 'Failed to send data');
        return false;
      }
    } catch (e) {
      _updateStatus(SyncStatus.error, 'Error: $e');
      return false;
    }
  }

  /// Request data from connected device
  Future<bool> requestFullSync() async {
    if (!_bluetoothService.isConnected) {
      _updateStatus(SyncStatus.error, 'No device connected');
      return false;
    }

    try {
      _updateStatus(SyncStatus.syncing, 'Requesting data...');

      final package = {
        'type': 'sync_request',
        'timestamp': DateTime.now().toIso8601String(),
      };

      bool success = await _bluetoothService.sendData(json.encode(package));

      if (success) {
        _updateStatus(SyncStatus.syncing, 'Waiting for response...');
        return true;
      } else {
        _updateStatus(SyncStatus.error, 'Failed to send request');
        return false;
      }
    } catch (e) {
      _updateStatus(SyncStatus.error, 'Error: $e');
      return false;
    }
  }

  /// Handle received data from Bluetooth
  Future<void> _handleReceivedData(String data) async {
    try {
      final package = json.decode(data) as Map<String, dynamic>;
      final type = package['type'] as String;

      switch (type) {
        case 'full_sync':
          await _handleFullSync(package['data'] as Map<String, dynamic>);
          break;
        case 'sync_request':
          await sendFullSync();
          break;
        case 'incremental_sync':
          await _handleIncrementalSync(package['data'] as Map<String, dynamic>);
          break;
        default:
          print('Unknown sync package type: $type');
      }
    } catch (e) {
      print('Error handling received data: $e');
      _updateStatus(SyncStatus.error, 'Error processing received data');
    }
  }

  /// Handle full sync data received
  Future<void> _handleFullSync(Map<String, dynamic> data) async {
    try {
      _updateStatus(SyncStatus.syncing, 'Merging data...');

      final receivedData = SyncData.fromMap(data);
      
      // Get local data
      final localProducts = await _productService.getProducts();
      final localSales = await _saleService.getSales();

      // Merge products with conflict resolution
      final mergedProducts = _mergeProducts(localProducts, receivedData.products);
      
      // Merge sales (sales are append-only, no conflicts)
      final mergedSales = _mergeSales(localSales, receivedData.sales);

      // Save merged data
      await _productService.saveProducts(mergedProducts);
      await _saleService.saveSales(mergedSales);

      _updateStatus(
        SyncStatus.success,
        'Synced ${mergedProducts.length} products and ${mergedSales.length} sales',
      );
    } catch (e) {
      _updateStatus(SyncStatus.error, 'Error merging data: $e');
    }
  }

  /// Handle incremental sync (single item updates)
  Future<void> _handleIncrementalSync(Map<String, dynamic> data) async {
    try {
      final itemType = data['itemType'] as String;
      
      if (itemType == 'product') {
        final product = Product.fromMap(data['item'] as Map<String, dynamic>);
        await _productService.updateProduct(product);
        _updateStatus(SyncStatus.success, 'Product updated: ${product.name}');
      } else if (itemType == 'sale') {
        final sale = Sale.fromMap(data['item'] as Map<String, dynamic>);
        final sales = await _saleService.getSales();
        final existingSaleIndex = sales.indexWhere((s) => s.id == sale.id);
        
        if (existingSaleIndex == -1) {
          await _saleService.addSale(sale);
          _updateStatus(SyncStatus.success, 'New sale added');
        }
      }
    } catch (e) {
      print('Error handling incremental sync: $e');
    }
  }

  /// Merge products with conflict resolution (newer timestamp wins)
  List<Product> _mergeProducts(List<Product> local, List<Product> remote) {
    final Map<String, Product> mergedMap = {};

    // Add all local products
    for (var product in local) {
      mergedMap[product.id] = product;
    }

    // Merge remote products (newer timestamp wins)
    for (var product in remote) {
      final existing = mergedMap[product.id];
      if (existing == null ||
          product.updatedAt.isAfter(existing.updatedAt)) {
        mergedMap[product.id] = product;
      }
    }

    return mergedMap.values.toList();
  }

  /// Merge sales (append-only, no conflicts)
  List<Sale> _mergeSales(List<Sale> local, List<Sale> remote) {
    final Map<String, Sale> mergedMap = {};

    // Add all local sales
    for (var sale in local) {
      mergedMap[sale.id] = sale;
    }

    // Add remote sales that don't exist locally
    for (var sale in remote) {
      if (!mergedMap.containsKey(sale.id)) {
        mergedMap[sale.id] = sale;
      }
    }

    // Sort by timestamp (newest first)
    final merged = mergedMap.values.toList();
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return merged;
  }

  /// Send incremental update for a single product
  Future<bool> syncProduct(Product product) async {
    if (!_bluetoothService.isConnected) {
      return false;
    }

    try {
      final package = {
        'type': 'incremental_sync',
        'data': {
          'itemType': 'product',
          'item': product.toMap(),
        },
      };

      return await _bluetoothService.sendData(json.encode(package));
    } catch (e) {
      print('Error syncing product: $e');
      return false;
    }
  }

  /// Send incremental update for a single sale
  Future<bool> syncSale(Sale sale) async {
    if (!_bluetoothService.isConnected) {
      return false;
    }

    try {
      final package = {
        'type': 'incremental_sync',
        'data': {
          'itemType': 'sale',
          'item': sale.toMap(),
        },
      };

      return await _bluetoothService.sendData(json.encode(package));
    } catch (e) {
      print('Error syncing sale: $e');
      return false;
    }
  }

  void dispose() {
    _syncStatusController.close();
    _syncMessageController.close();
  }
}
