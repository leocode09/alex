import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/account_history_record.dart';
import '../../models/category.dart';
import '../../models/customer.dart';
import '../../models/employee.dart';
import '../../models/expense.dart';
import '../../models/inventory_movement.dart';
import '../../models/money_account.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/store.dart';
import '../../models/sync_data.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/employee_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/inventory_movement_repository.dart';
import '../../repositories/money_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/sale_repository.dart';
import '../../repositories/store_repository.dart';
import '../sync_service.dart';
import 'cloud_entity_mapper.dart';
import 'firebase_init.dart';
import 'firestore_paths.dart';
import 'shop_service.dart';

enum CloudSyncStatus {
  disabled,
  notJoined,
  connecting,
  online,
  offline,
  error,
}

class CloudSyncAction {
  final DateTime at;
  final String reason;
  final String message;
  final bool success;

  CloudSyncAction({
    required this.reason,
    required this.message,
    required this.success,
  }) : at = DateTime.now();
}

/// Cloud backup + two-way sync service. Mirrors the surface of
/// [LanSyncService] so UI can treat it like a third peer:
///   - `start()` / `stop()`
///   - `triggerSync(reason:)` (debounced push)
///   - `status`, `logs`, `actions`, `lastError`
///   - `ChangeNotifier` updates + `connectionEvents` stream
///
/// Offline-first contract: this service must never throw from public APIs
/// and must never block the app. All Firestore calls are guarded; failures
/// are logged and the app keeps running off local storage.
class CloudSyncService extends ChangeNotifier {
  CloudSyncService._internal();

  static final CloudSyncService _instance = CloudSyncService._internal();

  factory CloudSyncService() => _instance;

  // Repositories (same singletons used everywhere else).
  final ProductRepository _productRepo = ProductRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final ExpenseRepository _expenseRepo = ExpenseRepository();
  final SaleRepository _saleRepo = SaleRepository();
  final StoreRepository _storeRepo = StoreRepository();
  final MoneyRepository _moneyRepo = MoneyRepository();
  final InventoryMovementRepository _movementRepo =
      InventoryMovementRepository();
  final SyncService _syncService = SyncService();
  final ShopService _shopService = ShopService();

  // Debounce / throttle (mirrors LanSyncService).
  static const Duration _syncDebounce = Duration(seconds: 2);
  static const Duration _minSyncInterval = Duration(seconds: 3);
  static const int _batchLimit = 450; // Firestore hard cap is 500.
  static const int _maxLogEntries = 80;
  static const int _maxActions = 200;

  Timer? _syncDebounceTimer;
  DateTime? _lastPushAt;
  bool _pushing = false;
  bool _pendingPush = false;

  CloudSyncStatus _status = CloudSyncStatus.disabled;
  String? _lastError;
  bool _running = false;
  String? _shopId;

  final List<String> _logs = [];
  final List<CloudSyncAction> _actions = [];

  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _listeners = {};

  CloudSyncStatus get status => _status;
  String? get lastError => _lastError;
  bool get isRunning => _running;
  String? get shopId => _shopId;
  String? get shopCode => _shopService.cachedShopCode;
  String? get shopName => _shopService.cachedShopName;
  List<String> get logs => List.unmodifiable(_logs);
  List<CloudSyncAction> get actions => List.unmodifiable(_actions);

  Future<void> start() async {
    if (_running) return;
    if (!FirebaseInit.available) {
      _setStatus(CloudSyncStatus.disabled);
      _addLog('Cloud sync disabled: Firebase not configured.');
      return;
    }

    _setStatus(CloudSyncStatus.connecting);
    await _shopService.loadCache();
    final uid = await _shopService.ensureAuth();
    if (uid == null) {
      _setStatus(CloudSyncStatus.error);
      _lastError = 'Unable to sign in to Firebase.';
      _addLog('Sign-in failed. Cloud sync paused.');
      notifyListeners();
      return;
    }

    _shopId = _shopService.cachedShopId;
    if (_shopId == null || _shopId!.isEmpty) {
      _setStatus(CloudSyncStatus.notJoined);
      _addLog('Signed in. Create or join a shop to enable cloud sync.');
      _running = true;
      notifyListeners();
      return;
    }

    _running = true;
    await _attachListeners();
    _setStatus(CloudSyncStatus.online);
    _addLog('Cloud sync online (shop $_shopId).');
    notifyListeners();

    // Push any local state that's newer than what the cloud has.
    unawaited(_pushDirty(reason: 'start'));
  }

  Future<void> stop() async {
    _running = false;
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = null;
    for (final sub in _listeners.values) {
      await sub.cancel();
    }
    _listeners.clear();
    _setStatus(CloudSyncStatus.disabled);
    _addLog('Cloud sync stopped.');
    notifyListeners();
  }

  /// Re-evaluate membership. Call after create/join/leave so listeners
  /// reattach to the new shop's subcollections.
  Future<void> refresh() async {
    await stop();
    await start();
  }

  /// Debounced push. Safe to call from write-hot paths.
  Future<void> triggerSync({required String reason}) async {
    if (!_running || !FirebaseInit.available) return;
    if (_shopId == null || _shopId!.isEmpty) return;

    _pendingPush = true;
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(_syncDebounce, () {
      final last = _lastPushAt;
      if (last != null && DateTime.now().difference(last) < _minSyncInterval) {
        // Too soon — reschedule one more time.
        _syncDebounceTimer = Timer(_minSyncInterval, () {
          unawaited(_pushDirty(reason: reason));
        });
        return;
      }
      unawaited(_pushDirty(reason: reason));
    });
  }

  /// Force a full upload regardless of the debounce / throttle.
  Future<void> forceFullSync() async {
    if (!_running) return;
    await _pushDirty(reason: 'manual_full');
  }

  // ======================= PUSH =======================

  Future<void> _pushDirty({required String reason}) async {
    if (_pushing) {
      _pendingPush = true;
      return;
    }
    _pushing = true;
    _pendingPush = false;
    final id = _shopId;
    if (id == null) {
      _pushing = false;
      return;
    }

    try {
      final snapshot = await _syncService.exportAllData();
      await _pushSnapshot(id, snapshot);
      _lastPushAt = DateTime.now();
      _addAction(reason: reason, message: 'Pushed snapshot.', success: true);
      if (_status != CloudSyncStatus.online) {
        _setStatus(CloudSyncStatus.online);
      }
    } catch (e) {
      _lastError = e.toString();
      _addLog('Push failed: $e');
      _addAction(reason: reason, message: 'Push failed: $e', success: false);
      // Firestore buffers writes while offline; most "failures" are network
      // hiccups that don't need escalation. Stay "online" unless it's a
      // configuration problem.
      if (_status == CloudSyncStatus.online) {
        _setStatus(CloudSyncStatus.offline);
      }
    } finally {
      _pushing = false;
      notifyListeners();
      if (_pendingPush) {
        _pendingPush = false;
        unawaited(_pushDirty(reason: 'coalesced'));
      }
    }
  }

  Future<void> _pushSnapshot(String shopId, SyncData data) async {
    final db = FirebaseFirestore.instance;
    final shopRef = db.collection(FirestorePaths.shopsCollection).doc(shopId);
    final deviceId = data.deviceId;

    // Collect (collectionName, docId, payload) tuples so we can chunk into
    // batches of up to [_batchLimit] writes each.
    final writes = <_PendingWrite>[];

    for (final p in data.products) {
      writes.add(_PendingWrite(
        FirestorePaths.productsSubcollection,
        p.id,
        CloudEntityMapper.productToDoc(p, deviceId: deviceId),
      ));
    }
    for (final id in data.deletedProductIds) {
      writes.add(_PendingWrite(
        FirestorePaths.productsSubcollection,
        id,
        _tombstoneDoc(id: id, deviceId: deviceId),
      ));
    }
    for (final c in data.categories) {
      writes.add(_PendingWrite(
        FirestorePaths.categoriesSubcollection,
        c.id,
        CloudEntityMapper.categoryToDoc(c, deviceId: deviceId),
      ));
    }
    for (final id in data.deletedCategoryIds) {
      writes.add(_PendingWrite(
        FirestorePaths.categoriesSubcollection,
        id,
        _tombstoneDoc(id: id, deviceId: deviceId),
      ));
    }
    for (final c in data.customers) {
      writes.add(_PendingWrite(
        FirestorePaths.customersSubcollection,
        c.id,
        CloudEntityMapper.customerToDoc(c, deviceId: deviceId),
      ));
    }
    for (final id in data.deletedCustomerIds) {
      writes.add(_PendingWrite(
        FirestorePaths.customersSubcollection,
        id,
        _tombstoneDoc(id: id, deviceId: deviceId),
      ));
    }
    for (final e in data.employees) {
      writes.add(_PendingWrite(
        FirestorePaths.employeesSubcollection,
        e.id,
        CloudEntityMapper.employeeToDoc(e, deviceId: deviceId),
      ));
    }
    for (final id in data.deletedEmployeeIds) {
      writes.add(_PendingWrite(
        FirestorePaths.employeesSubcollection,
        id,
        _tombstoneDoc(id: id, deviceId: deviceId),
      ));
    }
    for (final e in data.expenses) {
      writes.add(_PendingWrite(
        FirestorePaths.expensesSubcollection,
        e.id,
        CloudEntityMapper.expenseToDoc(e, deviceId: deviceId),
      ));
    }
    for (final id in data.deletedExpenseIds) {
      writes.add(_PendingWrite(
        FirestorePaths.expensesSubcollection,
        id,
        _tombstoneDoc(id: id, deviceId: deviceId),
      ));
    }
    for (final s in data.sales) {
      writes.add(_PendingWrite(
        FirestorePaths.salesSubcollection,
        s.id,
        CloudEntityMapper.saleToDoc(s, deviceId: deviceId),
      ));
    }
    for (final s in data.stores) {
      writes.add(_PendingWrite(
        FirestorePaths.storesSubcollection,
        s.id,
        CloudEntityMapper.storeToDoc(s, deviceId: deviceId),
      ));
    }
    for (final id in data.deletedStoreIds) {
      writes.add(_PendingWrite(
        FirestorePaths.storesSubcollection,
        id,
        _tombstoneDoc(id: id, deviceId: deviceId),
      ));
    }
    for (final a in data.moneyAccounts) {
      writes.add(_PendingWrite(
        FirestorePaths.moneyAccountsSubcollection,
        a.id,
        CloudEntityMapper.moneyAccountToDoc(a, deviceId: deviceId),
      ));
    }
    for (final id in data.deletedMoneyAccountIds) {
      writes.add(_PendingWrite(
        FirestorePaths.moneyAccountsSubcollection,
        id,
        _tombstoneDoc(id: id, deviceId: deviceId),
      ));
    }
    for (final r in data.moneyHistory) {
      writes.add(_PendingWrite(
        FirestorePaths.moneyHistorySubcollection,
        r.id,
        CloudEntityMapper.moneyHistoryToDoc(r, deviceId: deviceId),
      ));
    }
    for (final m in data.inventoryMovements) {
      writes.add(_PendingWrite(
        FirestorePaths.inventoryMovementsSubcollection,
        m.id,
        CloudEntityMapper.inventoryMovementToDoc(m, deviceId: deviceId),
      ));
    }

    if (writes.isEmpty) {
      return;
    }

    for (var i = 0; i < writes.length; i += _batchLimit) {
      final chunk = writes.sublist(
        i,
        (i + _batchLimit).clamp(0, writes.length),
      );
      final batch = db.batch();
      for (final w in chunk) {
        final ref = shopRef.collection(w.collection).doc(w.docId);
        batch.set(ref, w.payload, SetOptions(merge: true));
      }
      await batch.commit();
    }

    _addLog('Pushed ${writes.length} docs.');
  }

  Map<String, dynamic> _tombstoneDoc({
    required String id,
    required String deviceId,
  }) {
    return {
      'id': id,
      CloudFieldKeys.deleted: true,
      CloudFieldKeys.lastWriterDeviceId: deviceId,
      CloudFieldKeys.cloudUpdatedAt: FieldValue.serverTimestamp(),
    };
  }

  // ======================= PULL / LISTEN =======================

  Future<void> _attachListeners() async {
    final id = _shopId;
    if (id == null || id.isEmpty) return;

    for (final sub in _listeners.values) {
      await sub.cancel();
    }
    _listeners.clear();

    final prefs = await SharedPreferences.getInstance();
    for (final collection in FirestorePaths.syncedEntityCollections) {
      final cursor = _readCursor(prefs, collection);
      final query = FirebaseFirestore.instance
          .collection(FirestorePaths.shopsCollection)
          .doc(id)
          .collection(collection)
          .where(CloudFieldKeys.cloudUpdatedAt, isGreaterThan: cursor);

      _listeners[collection] = query.snapshots().listen(
        (snap) => _handleSnapshot(collection, snap),
        onError: (Object e) {
          _addLog('Listener error ($collection): $e');
          _lastError = e.toString();
          if (_status == CloudSyncStatus.online) {
            _setStatus(CloudSyncStatus.offline);
            notifyListeners();
          }
        },
      );
    }
  }

  Timestamp _readCursor(SharedPreferences prefs, String collection) {
    final key = _cursorKey(collection);
    final ms = prefs.getInt(key);
    if (ms == null) {
      return Timestamp.fromMillisecondsSinceEpoch(0);
    }
    return Timestamp.fromMillisecondsSinceEpoch(ms);
  }

  String _cursorKey(String collection) => 'cloud_last_pulled_$collection';

  Future<void> _handleSnapshot(
    String collection,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (snapshot.docChanges.isEmpty) return;

    try {
      final products = <Product>[];
      final categories = <Category>[];
      final customers = <Customer>[];
      final employees = <Employee>[];
      final expenses = <Expense>[];
      final sales = <Sale>[];
      final stores = <Store>[];
      final moneyAccounts = <MoneyAccount>[];
      final moneyHistory = <AccountHistoryRecord>[];
      final movements = <InventoryMovement>[];
      final deletedProductIds = <String>[];
      final deletedCategoryIds = <String>[];
      final deletedCustomerIds = <String>[];
      final deletedEmployeeIds = <String>[];
      final deletedExpenseIds = <String>[];
      final deletedStoreIds = <String>[];
      final deletedMoneyAccountIds = <String>[];

      Timestamp cursor = Timestamp.fromMillisecondsSinceEpoch(0);

      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final cloudTs = data[CloudFieldKeys.cloudUpdatedAt];
        if (cloudTs is Timestamp && cloudTs.compareTo(cursor) > 0) {
          cursor = cloudTs;
        }

        final deleted = CloudEntityMapper.isDeleted(data);
        final id = change.doc.id;

        switch (collection) {
          case FirestorePaths.productsSubcollection:
            if (deleted) {
              deletedProductIds.add(id);
            } else {
              final v = CloudEntityMapper.productFromDoc(data);
              if (v != null) products.add(v);
            }
            break;
          case FirestorePaths.categoriesSubcollection:
            if (deleted) {
              deletedCategoryIds.add(id);
            } else {
              final v = CloudEntityMapper.categoryFromDoc(data);
              if (v != null) categories.add(v);
            }
            break;
          case FirestorePaths.customersSubcollection:
            if (deleted) {
              deletedCustomerIds.add(id);
            } else {
              final v = CloudEntityMapper.customerFromDoc(data);
              if (v != null) customers.add(v);
            }
            break;
          case FirestorePaths.employeesSubcollection:
            if (deleted) {
              deletedEmployeeIds.add(id);
            } else {
              final v = CloudEntityMapper.employeeFromDoc(data);
              if (v != null) employees.add(v);
            }
            break;
          case FirestorePaths.expensesSubcollection:
            if (deleted) {
              deletedExpenseIds.add(id);
            } else {
              final v = CloudEntityMapper.expenseFromDoc(data);
              if (v != null) expenses.add(v);
            }
            break;
          case FirestorePaths.salesSubcollection:
            final v = CloudEntityMapper.saleFromDoc(data);
            if (v != null) sales.add(v);
            break;
          case FirestorePaths.storesSubcollection:
            if (deleted) {
              deletedStoreIds.add(id);
            } else {
              final v = CloudEntityMapper.storeFromDoc(data);
              if (v != null) stores.add(v);
            }
            break;
          case FirestorePaths.moneyAccountsSubcollection:
            if (deleted) {
              deletedMoneyAccountIds.add(id);
            } else {
              final v = CloudEntityMapper.moneyAccountFromDoc(data);
              if (v != null) moneyAccounts.add(v);
            }
            break;
          case FirestorePaths.moneyHistorySubcollection:
            final v = CloudEntityMapper.moneyHistoryFromDoc(data);
            if (v != null) moneyHistory.add(v);
            break;
          case FirestorePaths.inventoryMovementsSubcollection:
            final v = CloudEntityMapper.inventoryMovementFromDoc(data);
            if (v != null) movements.add(v);
            break;
        }
      }

      final hasPayload = products.isNotEmpty ||
          categories.isNotEmpty ||
          customers.isNotEmpty ||
          employees.isNotEmpty ||
          expenses.isNotEmpty ||
          sales.isNotEmpty ||
          stores.isNotEmpty ||
          moneyAccounts.isNotEmpty ||
          moneyHistory.isNotEmpty ||
          movements.isNotEmpty ||
          deletedProductIds.isNotEmpty ||
          deletedCategoryIds.isNotEmpty ||
          deletedCustomerIds.isNotEmpty ||
          deletedEmployeeIds.isNotEmpty ||
          deletedExpenseIds.isNotEmpty ||
          deletedStoreIds.isNotEmpty ||
          deletedMoneyAccountIds.isNotEmpty;

      if (!hasPayload) return;

      final deviceId = await _syncService.getDeviceId();
      final incoming = SyncData(
        products: products,
        categories: categories,
        customers: customers,
        employees: employees,
        expenses: expenses,
        sales: sales,
        stores: stores,
        moneyAccounts: moneyAccounts,
        moneyHistory: moneyHistory,
        inventoryMovements: movements,
        deletedProductIds: deletedProductIds,
        deletedCategoryIds: deletedCategoryIds,
        deletedCustomerIds: deletedCustomerIds,
        deletedEmployeeIds: deletedEmployeeIds,
        deletedExpenseIds: deletedExpenseIds,
        deletedStoreIds: deletedStoreIds,
        deletedMoneyAccountIds: deletedMoneyAccountIds,
        deviceId: deviceId,
      );

      final result = await _syncService.importData(
        incoming,
        strategy: SyncStrategy.merge,
      );

      if (cursor.toDate().millisecondsSinceEpoch > 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          _cursorKey(collection),
          cursor.toDate().millisecondsSinceEpoch,
        );
      }

      _addAction(
        reason: 'pull_$collection',
        message: 'Merged ${result.totalImported} items from $collection.',
        success: result.success,
      );
      if (_status != CloudSyncStatus.online) {
        _setStatus(CloudSyncStatus.online);
        notifyListeners();
      }
    } catch (e) {
      _addLog('Error handling $collection snapshot: $e');
    }
  }

  // ======================= STATUS / LOGGING =======================

  void _setStatus(CloudSyncStatus next) {
    if (_status == next) return;
    _status = next;
  }

  void _addLog(String message) {
    final stamp = DateTime.now().toIso8601String();
    _logs.insert(0, '[$stamp] $message');
    if (_logs.length > _maxLogEntries) {
      _logs.removeRange(_maxLogEntries, _logs.length);
    }
    if (kDebugMode) {
      debugPrint('CloudSync: $message');
    }
  }

  void _addAction({
    required String reason,
    required String message,
    required bool success,
  }) {
    _actions.insert(
      0,
      CloudSyncAction(reason: reason, message: message, success: success),
    );
    if (_actions.length > _maxActions) {
      _actions.removeRange(_maxActions, _actions.length);
    }
    _addLog('[$reason] $message');
  }
}

class _PendingWrite {
  final String collection;
  final String docId;
  final Map<String, dynamic> payload;

  const _PendingWrite(this.collection, this.docId, this.payload);
}
