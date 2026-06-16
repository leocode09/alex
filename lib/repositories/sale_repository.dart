import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/sale.dart';
import '../services/admin/usage_recorder.dart';
import '../services/database_helper.dart';
import '../services/db/app_database.dart';

/// Outcome of [SaleRepository.recordCustomerPayment]. Contains the freshly
/// mutated sales (so callers can reprint each receipt) plus any leftover
/// overpayment that fell outside the customer's outstanding balance.
class CustomerPaymentResult {
  final List<Sale> updatedSales;
  final double leftover;
  final double totalApplied;

  const CustomerPaymentResult({
    required this.updatedSales,
    required this.leftover,
    required this.totalApplied,
  });

  bool get didApplyAnything => updatedSales.isNotEmpty;
}

/// Sales ledger repository.
///
/// Backed by an indexed SQLite table ([AppDatabase]) so the ledger stays
/// light and fast as the shop trades. If SQLite cannot be opened on a given
/// platform the repository transparently falls back to the legacy
/// SharedPreferences JSON blob so the app never loses access to sales.
class SaleRepository {
  final StorageHelper _storage = StorageHelper();
  final AppDatabase _appDb = AppDatabase.instance;

  static const String _salesKey = 'sales';
  static const String _deletedSaleIdsKey = 'deleted_sale_ids';
  static const double _epsilon = 0.000001;

  bool? _dbReady;

  /// Lazily resolve whether the SQLite ledger is usable. Cached after the
  /// first attempt. On failure we fall back to the legacy blob.
  Future<bool> _ready() async {
    final cached = _dbReady;
    if (cached != null) return cached;
    try {
      await _appDb.database;
      _dbReady = true;
    } catch (e) {
      print('SaleRepository: SQLite unavailable, using legacy storage -> $e');
      _dbReady = false;
    }
    return _dbReady!;
  }

  // ======================= READS =======================

  /// All locally-retained sales, newest first. After the retention policy
  /// runs this is bounded (~recent window) instead of the full history.
  Future<List<Sale>> getAllSales() async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final rows = await db.query(
          AppDatabase.tableSales,
          columns: ['data'],
          orderBy: 'created_at DESC',
        );
        return rows.map((r) => _decode(r['data'] as String)).toList();
      }
    } catch (e) {
      print('Error getting all sales (sqlite): $e');
    }
    return _legacyGetAll();
  }

  Future<Sale?> getSaleById(String id) async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final rows = await db.query(
          AppDatabase.tableSales,
          columns: ['data'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isEmpty) return null;
        return _decode(rows.first['data'] as String);
      }
    } catch (e) {
      print('Error getting sale by id: $e');
    }
    final all = await _legacyGetAll();
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // ======================= WRITES =======================

  Future<bool> insertSale(Sale sale) async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        await _writeSale(db, sale, backedUp: false);
        unawaited(UsageRecorder().recordSale(amount: sale.total));
        return true;
      }
    } catch (e) {
      print('Error inserting sale (sqlite): $e');
    }
    final sales = await _legacyGetAll();
    sales.add(sale);
    final saved = await _legacySaveAll(sales);
    if (saved) {
      unawaited(UsageRecorder().recordSale(amount: sale.total));
    }
    return saved;
  }

  Future<bool> updateSale(Sale updatedSale) async {
    final stamped = updatedSale.copyWith(updatedAt: DateTime.now());
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final existing = await db.query(
          AppDatabase.tableSales,
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [updatedSale.id],
          limit: 1,
        );
        if (existing.isEmpty) return false;
        await _writeSale(db, stamped, backedUp: false);
        return true;
      }
    } catch (e) {
      print('Error updating sale (sqlite): $e');
    }
    final sales = await _legacyGetAll();
    final index = sales.indexWhere((s) => s.id == updatedSale.id);
    if (index == -1) return false;
    sales[index] = stamped;
    return _legacySaveAll(sales);
  }

  Future<bool> deleteSale(String id) async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final count = await db.delete(
          AppDatabase.tableSales,
          where: 'id = ?',
          whereArgs: [id],
        );
        await db.delete(
          AppDatabase.tableSaleItems,
          where: 'sale_id = ?',
          whereArgs: [id],
        );
        if (count == 0) return false;
        await addDeletedSaleIds([id]);
        return true;
      }
    } catch (e) {
      print('Error deleting sale (sqlite): $e');
    }
    final sales = await _legacyGetAll();
    final initialLength = sales.length;
    sales.removeWhere((s) => s.id == id);
    if (sales.length == initialLength) return false;
    final saved = await _legacySaveAll(sales);
    if (saved) {
      await addDeletedSaleIds([id]);
    }
    return saved;
  }

  /// Replace the entire local sales set (used by sync merge/replace/append).
  ///
  /// The `backed_up` flag is preserved per-id so the retention policy keeps
  /// working across syncs.
  Future<bool> replaceAllSales(List<Sale> sales) async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final existing = await db.query(
          AppDatabase.tableSales,
          columns: ['id', 'backed_up'],
        );
        final backedUpById = <String, bool>{
          for (final r in existing)
            (r['id'] as String): ((r['backed_up'] as int?) ?? 0) == 1,
        };
        await db.transaction((txn) async {
          await txn.delete(AppDatabase.tableSales);
          await txn.delete(AppDatabase.tableSaleItems);
          final batch = txn.batch();
          for (final sale in sales) {
            _appDb.writeSaleMapToBatch(
              batch,
              sale.toMap(),
              backedUp: backedUpById[sale.id] ?? false,
            );
          }
          await batch.commit(noResult: true);
        });
        return true;
      }
    } catch (e) {
      print('Error replacing all sales (sqlite): $e');
    }
    return _legacySaveAll(sales);
  }

  // ======================= DATE RANGE / AGGREGATES =======================

  /// Sales strictly inside (start, end), preserving the legacy exclusive
  /// boundary semantics.
  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final rows = await db.query(
          AppDatabase.tableSales,
          columns: ['data'],
          where: 'created_at > ? AND created_at < ?',
          whereArgs: [
            start.millisecondsSinceEpoch,
            end.millisecondsSinceEpoch,
          ],
          orderBy: 'created_at DESC',
        );
        return rows.map((r) => _decode(r['data'] as String)).toList();
      }
    } catch (e) {
      print('Error getting sales by date range: $e');
    }
    final sales = await _legacyGetAll();
    return sales
        .where((s) => s.createdAt.isAfter(start) && s.createdAt.isBefore(end))
        .toList();
  }

  Future<double> _revenueBetween(DateTime start, DateTime end) async {
    if (await _ready()) {
      final db = await _appDb.database;
      final rows = await db.rawQuery(
        'SELECT SUM(total) AS revenue FROM ${AppDatabase.tableSales} '
        'WHERE created_at > ? AND created_at < ?',
        [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      );
      return (rows.first['revenue'] as num?)?.toDouble() ?? 0.0;
    }
    final sales = await getSalesByDateRange(start, end);
    return sales.fold<double>(0.0, (sum, s) => sum + s.total);
  }

  Future<List<Sale>> getTodaysSales() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return getSalesByDateRange(startOfDay, endOfDay);
  }

  Future<int> getTotalSalesCount() async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final rows = await db
            .rawQuery('SELECT COUNT(*) AS c FROM ${AppDatabase.tableSales}');
        return (rows.first['c'] as int?) ?? 0;
      }
    } catch (e) {
      print('Error counting sales: $e');
    }
    return (await _legacyGetAll()).length;
  }

  Future<int> getTodaysSalesCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final rows = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM ${AppDatabase.tableSales} '
          'WHERE created_at > ? AND created_at < ?',
          [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch],
        );
        return (rows.first['c'] as int?) ?? 0;
      }
    } catch (e) {
      print('Error counting today sales: $e');
    }
    return (await getTodaysSales()).length;
  }

  Future<double> getTotalRevenue() async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final rows = await db.rawQuery(
          'SELECT SUM(total) AS revenue FROM ${AppDatabase.tableSales}',
        );
        return (rows.first['revenue'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      print('Error summing revenue: $e');
    }
    final sales = await _legacyGetAll();
    return sales.fold<double>(0.0, (sum, s) => sum + s.total);
  }

  Future<double> getTodaysRevenue() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return _revenueBetween(startOfDay, endOfDay);
  }

  Future<List<Sale>> getYesterdaysSales() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final startOfDay = DateTime(yesterday.year, yesterday.month, yesterday.day);
    final endOfDay =
        DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
    return getSalesByDateRange(startOfDay, endOfDay);
  }

  Future<int> getYesterdaysSalesCount() async {
    return (await getYesterdaysSales()).length;
  }

  Future<double> getYesterdaysRevenue() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final startOfDay = DateTime(yesterday.year, yesterday.month, yesterday.day);
    final endOfDay =
        DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
    return _revenueBetween(startOfDay, endOfDay);
  }

  Future<List<Sale>> getWeeklySales() async {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return getSalesByDateRange(startOfWeek, endOfDay);
  }

  Future<double> getWeeklyRevenue() async {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return _revenueBetween(startOfWeek, endOfDay);
  }

  Future<double> getLastWeekRevenue() async {
    final now = DateTime.now();
    final startOfLastWeek = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 13));
    final endOfLastWeek = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 7));
    return _revenueBetween(startOfLastWeek, endOfLastWeek);
  }

  Future<List<Sale>> getSalesByPaymentMethod(String paymentMethod) async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final rows = await db.query(
          AppDatabase.tableSales,
          columns: ['data'],
          where: 'payment_method = ?',
          whereArgs: [paymentMethod],
          orderBy: 'created_at DESC',
        );
        return rows.map((r) => _decode(r['data'] as String)).toList();
      }
    } catch (e) {
      print('Error getting sales by payment method: $e');
    }
    final sales = await _legacyGetAll();
    return sales.where((s) => s.paymentMethod == paymentMethod).toList();
  }

  Future<List<Sale>> getSalesByEmployee(String employeeId) async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final rows = await db.query(
          AppDatabase.tableSales,
          columns: ['data'],
          where: 'employee_id = ?',
          whereArgs: [employeeId],
          orderBy: 'created_at DESC',
        );
        return rows.map((r) => _decode(r['data'] as String)).toList();
      }
    } catch (e) {
      print('Error getting sales by employee: $e');
    }
    final sales = await _legacyGetAll();
    return sales.where((s) => s.employeeId == employeeId).toList();
  }

  Future<List<Sale>> getSalesByCustomer(String customerId) async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final rows = await db.query(
          AppDatabase.tableSales,
          columns: ['data'],
          where: 'customer_id = ?',
          whereArgs: [customerId],
          orderBy: 'created_at DESC',
        );
        return rows.map((r) => _decode(r['data'] as String)).toList();
      }
    } catch (e) {
      print('Error getting sales by customer: $e');
    }
    final sales = await _legacyGetAll();
    return sales.where((s) => s.customerId == customerId).toList();
  }

  /// Top selling products by base units sold, computed in SQL via the
  /// `sale_items` child table (no full-ledger scan).
  Future<Map<String, int>> getTopSellingProducts({int limit = 10}) async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final rows = await db.rawQuery(
          'SELECT product_name AS name, SUM(base_units) AS units '
          'FROM ${AppDatabase.tableSaleItems} '
          'GROUP BY product_name ORDER BY units DESC LIMIT ?',
          [limit],
        );
        return {
          for (final r in rows)
            (r['name'] as String? ?? ''): (r['units'] as num?)?.toInt() ?? 0,
        };
      }
    } catch (e) {
      print('Error computing top products: $e');
    }
    final sales = await _legacyGetAll();
    final Map<String, int> productCounts = {};
    for (var sale in sales) {
      for (var item in sale.items) {
        productCounts[item.productName] =
            (productCounts[item.productName] ?? 0) + item.baseUnitsSold;
      }
    }
    final sortedEntries = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries.take(limit));
  }

  /// Page of receipts (newest first) for paginated UI lists.
  Future<List<Sale>> getSalesPage({int limit = 50, int offset = 0}) async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final rows = await db.query(
          AppDatabase.tableSales,
          columns: ['data'],
          orderBy: 'created_at DESC',
          limit: limit,
          offset: offset,
        );
        return rows.map((r) => _decode(r['data'] as String)).toList();
      }
    } catch (e) {
      print('Error paging sales: $e');
    }
    final sales = await _legacyGetAll();
    if (offset >= sales.length) return const [];
    return sales.skip(offset).take(limit).toList();
  }

  // ======================= CUSTOMER PAYMENTS =======================

  Future<CustomerPaymentResult> recordCustomerPayment({
    required String customerId,
    required double amount,
    String? saleId,
  }) async {
    if (amount <= 0) {
      return const CustomerPaymentResult(
          updatedSales: [], leftover: 0.0, totalApplied: 0.0);
    }

    List<Sale> unpaid;
    if (await _ready()) {
      final db = await _appDb.database;
      final rows = await db.query(
        AppDatabase.tableSales,
        columns: ['data'],
        where: saleId == null
            ? 'customer_id = ? AND amount_due > ?'
            : 'customer_id = ? AND amount_due > ? AND id = ?',
        whereArgs: saleId == null
            ? [customerId, _epsilon]
            : [customerId, _epsilon, saleId],
        orderBy: 'created_at ASC',
      );
      unpaid = rows.map((r) => _decode(r['data'] as String)).toList();
    } else {
      final sales = await _legacyGetAll();
      unpaid = sales
          .where((s) =>
              s.customerId == customerId &&
              s.amountDue > _epsilon &&
              (saleId == null || s.id == saleId))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    if (unpaid.isEmpty) {
      return CustomerPaymentResult(
          updatedSales: const [], leftover: amount, totalApplied: 0.0);
    }

    final updatedSales = <Sale>[];
    double remaining = amount;
    for (var i = 0; i < unpaid.length && remaining > _epsilon; i++) {
      final sale = unpaid[i];
      final due = sale.amountDue;
      final applied = remaining < due ? remaining : due;
      final updated = sale.copyWith(
        amountPaid: sale.amountPaid + applied,
        updatedAt: DateTime.now(),
      );
      final ok = await updateSale(updated);
      if (ok) {
        updatedSales.add(updated);
        remaining -= applied;
      }
    }

    final leftover = remaining > _epsilon ? remaining : 0.0;
    return CustomerPaymentResult(
      updatedSales: updatedSales,
      leftover: leftover,
      totalApplied: amount - leftover,
    );
  }

  Future<double> getCustomerAmountDue(String customerId) async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final rows = await db.rawQuery(
          'SELECT SUM(amount_due) AS due FROM ${AppDatabase.tableSales} '
          'WHERE customer_id = ?',
          [customerId],
        );
        return (rows.first['due'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      print('Error summing customer due: $e');
    }
    final sales = await _legacyGetAll();
    return sales
        .where((s) => s.customerId == customerId)
        .fold<double>(0.0, (sum, s) => sum + s.amountDue);
  }

  // ======================= TOMBSTONES =======================

  Future<List<String>> getDeletedSaleIds() async {
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final rows = await db.query(
          AppDatabase.tableDeletedSaleIds,
          columns: ['id'],
        );
        return rows.map((r) => r['id'] as String).toList();
      }
    } catch (e) {
      print('Error reading deleted sale ids: $e');
    }
    final jsonData = await _storage.getData(_deletedSaleIdsKey);
    if (jsonData == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonData);
      return decoded.cast<String>();
    } catch (e) {
      return [];
    }
  }

  Future<void> addDeletedSaleIds(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        final batch = db.batch();
        for (final id in ids) {
          batch.insert(
            AppDatabase.tableDeletedSaleIds,
            {'id': id},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        await batch.commit(noResult: true);
        return;
      }
    } catch (e) {
      print('Error adding deleted sale ids: $e');
    }
    final existing = (await getDeletedSaleIds()).toSet();
    existing.addAll(ids);
    await _storage.saveData(_deletedSaleIdsKey, jsonEncode(existing.toList()));
  }

  Future<void> applyDeletedSaleIds(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      if (await _ready()) {
        final db = await _appDb.database;
        await db.transaction((txn) async {
          final batch = txn.batch();
          for (final id in ids) {
            batch.delete(AppDatabase.tableSales,
                where: 'id = ?', whereArgs: [id]);
            batch.delete(AppDatabase.tableSaleItems,
                where: 'sale_id = ?', whereArgs: [id]);
            batch.insert(
              AppDatabase.tableDeletedSaleIds,
              {'id': id},
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
          await batch.commit(noResult: true);
        });
        return;
      }
    } catch (e) {
      print('Error applying deleted sale ids: $e');
    }
    final deletedSet = ids.toSet();
    final sales = await _legacyGetAll();
    final filtered = sales.where((s) => !deletedSet.contains(s.id)).toList();
    if (filtered.length < sales.length) {
      await _legacySaveAll(filtered);
    }
    await addDeletedSaleIds(ids);
  }

  // ======================= RETENTION / BACKUP =======================

  /// Date below which paid sales are no longer kept locally (they remain in
  /// the cloud backup). Used by sync to avoid re-importing evicted rows.
  /// Null when retention has never run (or SQLite unavailable) so callers
  /// never skip importing data.
  Future<DateTime?> getRetentionWatermark() async {
    if (!await _ready()) return null;
    final raw = await _appDb.getMeta(AppDatabase.metaRetentionFromMs);
    if (raw == null) return null;
    final ms = int.tryParse(raw);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setRetentionWatermark(DateTime from) async {
    if (!await _ready()) return;
    // Monotonic: never move the watermark backwards.
    final current = await getRetentionWatermark();
    if (current != null && current.isAfter(from)) return;
    await _appDb.setMeta(
      AppDatabase.metaRetentionFromMs,
      from.millisecondsSinceEpoch.toString(),
    );
  }

  /// Mark every locally-stored sale as confirmed-backed-up. Called after a
  /// successful full cloud push (which uploads all local sales).
  Future<void> markAllLocalSalesBackedUp() async {
    if (!await _ready()) return;
    final db = await _appDb.database;
    await db.update(AppDatabase.tableSales, {'backed_up': 1});
  }

  Future<void> markSalesBackedUp(List<String> ids) async {
    if (ids.isEmpty || !await _ready()) return;
    final db = await _appDb.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE ${AppDatabase.tableSales} SET backed_up = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  /// Ids of paid, confirmed-backed-up sales created before [before].
  /// These are safe to evict locally (full history stays in the cloud).
  Future<List<String>> getEvictableSaleIds(DateTime before) async {
    if (!await _ready()) return const [];
    final db = await _appDb.database;
    final rows = await db.query(
      AppDatabase.tableSales,
      columns: ['id'],
      where: 'created_at < ? AND amount_due <= ? AND backed_up = 1',
      whereArgs: [before.millisecondsSinceEpoch, _epsilon],
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  /// Evict (drop locally) the given sales WITHOUT writing tombstones, so the
  /// cloud backup is preserved and the rows are not deleted on other devices.
  Future<int> evictSalesLocally(List<String> ids) async {
    if (ids.isEmpty || !await _ready()) return 0;
    final db = await _appDb.database;
    var removed = 0;
    await db.transaction((txn) async {
      for (final id in ids) {
        removed += await txn.delete(
          AppDatabase.tableSales,
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          AppDatabase.tableSaleItems,
          where: 'sale_id = ?',
          whereArgs: [id],
        );
      }
    });
    return removed;
  }

  // ======================= INTERNALS =======================

  Sale _decode(String json) =>
      Sale.fromMap(Map<String, dynamic>.from(jsonDecode(json) as Map));

  /// Upsert a single sale (row + child items). Any content write marks the
  /// row as not-yet-backed-up so retention won't evict unsynced edits.
  Future<void> _writeSale(
    Database db,
    Sale sale, {
    required bool backedUp,
  }) async {
    await db.transaction((txn) async {
      final batch = txn.batch();
      _appDb.writeSaleMapToBatch(batch, sale.toMap(), backedUp: backedUp);
      await batch.commit(noResult: true);
    });
  }

  // ---- legacy SharedPreferences blob fallback ----

  Future<List<Sale>> _legacyGetAll() async {
    try {
      final jsonData = await _storage.getData(_salesKey);
      if (jsonData == null) return [];
      final List<dynamic> decoded = jsonDecode(jsonData);
      final sales = decoded.map((json) => Sale.fromMap(json)).toList();
      sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sales;
    } catch (e) {
      print('Error getting all sales (legacy): $e');
      return [];
    }
  }

  Future<bool> _legacySaveAll(List<Sale> sales) async {
    try {
      final jsonList = sales.map((s) => s.toMap()).toList();
      return await _storage.saveData(_salesKey, jsonEncode(jsonList));
    } catch (e) {
      print('Error saving sales (legacy): $e');
      return false;
    }
  }
}
