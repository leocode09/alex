import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database_helper.dart';

/// Single SQLite database used for the high-volume, unbounded sales ledger.
///
/// Why only sales live here: bounded collections (products, customers,
/// categories, employees, stores, money accounts) stay on the existing
/// SharedPreferences-backed [StorageHelper] because they never grow without
/// bound. Sales are the one collection that keeps growing as the shop trades,
/// so they get per-row indexed storage (and SQL aggregation for reports/
/// dashboard) plus a retention policy that evicts old, backed-up rows.
///
/// The schema keeps the full `Sale.toMap()` JSON in a `data` column for 100%
/// model fidelity, while extracting a few indexed columns used by hot queries
/// (date ranges, customer lookups, unpaid filters) and a child `sale_items`
/// table that powers fast `GROUP BY` aggregation (top products, per-product
/// stats) without scanning every sale.
class AppDatabase {
  AppDatabase._internal();

  static final AppDatabase instance = AppDatabase._internal();

  static const String dbFileName = 'alex_pos.db';
  static const int _schemaVersion = 1;

  // Tables.
  static const String tableSales = 'sales';
  static const String tableSaleItems = 'sale_items';
  static const String tableDeletedSaleIds = 'deleted_sale_ids';
  static const String tableMeta = 'app_meta';

  // Meta keys.
  static const String metaSalesMigrated = 'sales_migrated_v1';
  static const String metaRetentionFromMs = 'sales_retention_from_ms';

  Database? _db;
  Completer<Database>? _opening;

  /// Whether [Sale] storage successfully initialized. When false the
  /// repository falls back to the legacy SharedPreferences blob so the app
  /// never loses the ability to read/write sales.
  bool get isReady => _db != null;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final inFlight = _opening;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<Database>();
    _opening = completer;
    try {
      final db = await _open();
      _db = db;
      completer.complete(db);
      return db;
    } catch (e, st) {
      _opening = null;
      completer.completeError(e, st);
      rethrow;
    }
  }

  Future<Database> _open() async {
    final factory = _resolveFactory();
    final basePath = await factory.getDatabasesPath();
    final path = _join(basePath, dbFileName);
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onConfigure: (db) async {
          // Better concurrency + durability for a write-hot ledger.
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createSchema(db);
          await _migrateFromSharedPreferences(db);
        },
      ),
    );
  }

  DatabaseFactory _resolveFactory() {
    // Android/iOS ship the native sqflite plugin. Desktop (and tests) use the
    // FFI implementation. Web is not a runtime target for this POS app.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  String _join(String base, String file) {
    if (base.endsWith('/') || base.endsWith('\\')) {
      return '$base$file';
    }
    final sep = base.contains('\\') ? '\\' : '/';
    return '$base$sep$file';
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $tableSales (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        customer_id TEXT,
        payment_method TEXT,
        employee_id TEXT,
        total REAL NOT NULL DEFAULT 0,
        amount_paid REAL NOT NULL DEFAULT 0,
        amount_due REAL NOT NULL DEFAULT 0,
        backed_up INTEGER NOT NULL DEFAULT 0,
        data TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_sales_created_at ON $tableSales(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_sales_customer ON $tableSales(customer_id)',
    );
    await db.execute(
      'CREATE INDEX idx_sales_due ON $tableSales(amount_due)',
    );

    await db.execute('''
      CREATE TABLE $tableSaleItems (
        sale_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT,
        quantity INTEGER NOT NULL DEFAULT 0,
        base_units INTEGER NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0,
        cost_price REAL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_items_sale ON $tableSaleItems(sale_id)',
    );
    await db.execute(
      'CREATE INDEX idx_items_product ON $tableSaleItems(product_id)',
    );
    await db.execute(
      'CREATE INDEX idx_items_created ON $tableSaleItems(created_at)',
    );

    await db.execute('''
      CREATE TABLE $tableDeletedSaleIds (
        id TEXT PRIMARY KEY
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableMeta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  /// One-time copy of the legacy SharedPreferences sales blob into SQLite.
  ///
  /// The original blob is intentionally left untouched so a faulty migration
  /// can be rolled back. Runs inside [onCreate] (i.e. exactly once, when the
  /// DB file is first created).
  Future<void> _migrateFromSharedPreferences(Database db) async {
    try {
      final storage = StorageHelper();
      final salesJson = await storage.getData('sales');
      if (salesJson != null && salesJson.isNotEmpty) {
        final decoded = jsonDecode(salesJson);
        if (decoded is List) {
          final batch = db.batch();
          for (final raw in decoded) {
            if (raw is! Map) continue;
            final map = Map<String, dynamic>.from(raw);
            _insertSaleMapIntoBatch(batch, map, backedUp: false);
          }
          await batch.commit(noResult: true);
        }
      }

      final deletedJson = await storage.getData('deleted_sale_ids');
      if (deletedJson != null && deletedJson.isNotEmpty) {
        final decoded = jsonDecode(deletedJson);
        if (decoded is List) {
          final batch = db.batch();
          for (final id in decoded) {
            batch.insert(
              tableDeletedSaleIds,
              {'id': id.toString()},
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
          await batch.commit(noResult: true);
        }
      }

      await db.insert(
        tableMeta,
        {'key': metaSalesMigrated, 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppDatabase: sales migration skipped -> $e');
      }
    }
  }

  /// Writes a sale (given its `toMap()` form) into a batch as table rows.
  /// Shared by migration and the repository so column extraction stays
  /// consistent.
  void _insertSaleMapIntoBatch(
    Batch batch,
    Map<String, dynamic> map, {
    required bool backedUp,
  }) {
    final id = map['id']?.toString();
    if (id == null || id.isEmpty) return;

    final total = (map['total'] as num?)?.toDouble() ?? 0.0;
    final amountPaid =
        (map['amountPaid'] as num?)?.toDouble() ?? total;
    final due = (total - amountPaid) > 0 ? (total - amountPaid) : 0.0;
    final createdAtMs = _parseMs(map['createdAt']);
    final updatedAtMs = map['updatedAt'] != null
        ? _parseMs(map['updatedAt'])
        : createdAtMs;

    batch.insert(
      tableSales,
      {
        'id': id,
        'created_at': createdAtMs,
        'updated_at': updatedAtMs,
        'customer_id': map['customerId'],
        'payment_method': map['paymentMethod'],
        'employee_id': map['employeeId'],
        'total': total,
        'amount_paid': amountPaid,
        'amount_due': due,
        'backed_up': backedUp ? 1 : 0,
        'data': jsonEncode(map),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    batch.delete(tableSaleItems, where: 'sale_id = ?', whereArgs: [id]);
    final items = map['items'];
    if (items is List) {
      for (final rawItem in items) {
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        final unitsPerPackage = (item['unitsPerPackage'] as num?)?.toInt();
        final baseUnits =
            unitsPerPackage != null ? quantity * unitsPerPackage : quantity;
        batch.insert(tableSaleItems, {
          'sale_id': id,
          'product_id': item['productId'],
          'product_name': item['productName'],
          'quantity': quantity,
          'base_units': baseUnits,
          'subtotal': (item['subtotal'] as num?)?.toDouble() ?? 0.0,
          'cost_price': (item['costPrice'] as num?)?.toDouble(),
          'created_at': createdAtMs,
        });
      }
    }
  }

  static int _parseMs(dynamic isoOrMs) {
    if (isoOrMs is int) return isoOrMs;
    if (isoOrMs is num) return isoOrMs.toInt();
    if (isoOrMs is String) {
      try {
        return DateTime.parse(isoOrMs).millisecondsSinceEpoch;
      } catch (_) {
        return DateTime.now().millisecondsSinceEpoch;
      }
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  // ---- meta helpers ----

  Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query(
      tableMeta,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert(
      tableMeta,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Exposes the shared row-extraction helper to the repository so insert /
  /// update / replace all go through identical column mapping.
  void writeSaleMapToBatch(
    Batch batch,
    Map<String, dynamic> map, {
    required bool backedUp,
  }) =>
      _insertSaleMapIntoBatch(batch, map, backedUp: backedUp);
}
