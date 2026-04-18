import 'package:cloud_firestore/cloud_firestore.dart';

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

/// Extra keys stamped on every Firestore entity doc (in addition to the
/// model's normal toMap payload).
class CloudFieldKeys {
  const CloudFieldKeys._();

  /// Soft-delete flag. Present on every mutable entity collection.
  static const String deleted = 'deleted';

  /// Server timestamp set on every write; used as the listener cursor.
  static const String cloudUpdatedAt = 'cloudUpdatedAt';

  /// The device that last pushed this doc (informational, for debugging).
  static const String lastWriterDeviceId = 'lastWriterDeviceId';
}

/// Two-way mapping between model objects and Firestore document payloads.
///
/// Every entity is round-tripped through its existing `toMap` / `fromMap`
/// (which already produces JSON-friendly values), then we stamp cloud-only
/// fields (`deleted`, `cloudUpdatedAt`) for sync bookkeeping. On pull, we
/// strip those fields before handing the map to `fromMap`.
class CloudEntityMapper {
  const CloudEntityMapper._();

  static Map<String, dynamic> productToDoc(
    Product product, {
    required String deviceId,
    bool deleted = false,
  }) =>
      _stamp(product.toMap(), deviceId: deviceId, deleted: deleted);

  static Map<String, dynamic> categoryToDoc(
    Category category, {
    required String deviceId,
    bool deleted = false,
  }) =>
      _stamp(category.toMap(), deviceId: deviceId, deleted: deleted);

  static Map<String, dynamic> customerToDoc(
    Customer customer, {
    required String deviceId,
    bool deleted = false,
  }) =>
      _stamp(customer.toMap(), deviceId: deviceId, deleted: deleted);

  static Map<String, dynamic> employeeToDoc(
    Employee employee, {
    required String deviceId,
    bool deleted = false,
  }) =>
      _stamp(employee.toMap(), deviceId: deviceId, deleted: deleted);

  static Map<String, dynamic> expenseToDoc(
    Expense expense, {
    required String deviceId,
    bool deleted = false,
  }) =>
      _stamp(expense.toMap(), deviceId: deviceId, deleted: deleted);

  static Map<String, dynamic> saleToDoc(
    Sale sale, {
    required String deviceId,
  }) =>
      _stamp(sale.toMap(), deviceId: deviceId, deleted: false);

  static Map<String, dynamic> storeToDoc(
    Store store, {
    required String deviceId,
    bool deleted = false,
  }) =>
      _stamp(store.toMap(), deviceId: deviceId, deleted: deleted);

  static Map<String, dynamic> moneyAccountToDoc(
    MoneyAccount account, {
    required String deviceId,
    bool deleted = false,
  }) =>
      _stamp(account.toMap(), deviceId: deviceId, deleted: deleted);

  static Map<String, dynamic> moneyHistoryToDoc(
    AccountHistoryRecord record, {
    required String deviceId,
  }) =>
      _stamp(record.toMap(), deviceId: deviceId, deleted: false);

  static Map<String, dynamic> inventoryMovementToDoc(
    InventoryMovement movement, {
    required String deviceId,
  }) =>
      _stamp(movement.toMap(), deviceId: deviceId, deleted: false);

  // ---- fromDoc ----

  static Product? productFromDoc(Map<String, dynamic> doc) =>
      _safeDecode(doc, (m) => Product.fromMap(m));

  static Category? categoryFromDoc(Map<String, dynamic> doc) =>
      _safeDecode(doc, (m) => Category.fromMap(m));

  static Customer? customerFromDoc(Map<String, dynamic> doc) =>
      _safeDecode(doc, (m) => Customer.fromMap(m));

  static Employee? employeeFromDoc(Map<String, dynamic> doc) =>
      _safeDecode(doc, (m) => Employee.fromMap(m));

  static Expense? expenseFromDoc(Map<String, dynamic> doc) =>
      _safeDecode(doc, (m) => Expense.fromMap(m));

  static Sale? saleFromDoc(Map<String, dynamic> doc) =>
      _safeDecode(doc, (m) => Sale.fromMap(m));

  static Store? storeFromDoc(Map<String, dynamic> doc) =>
      _safeDecode(doc, (m) => Store.fromMap(m));

  static MoneyAccount? moneyAccountFromDoc(Map<String, dynamic> doc) =>
      _safeDecode(doc, (m) => MoneyAccount.fromMap(m));

  static AccountHistoryRecord? moneyHistoryFromDoc(Map<String, dynamic> doc) =>
      _safeDecode(doc, (m) => AccountHistoryRecord.fromMap(m));

  static InventoryMovement? inventoryMovementFromDoc(
          Map<String, dynamic> doc) =>
      _safeDecode(doc, (m) => InventoryMovement.fromMap(m));

  static bool isDeleted(Map<String, dynamic> doc) =>
      doc[CloudFieldKeys.deleted] == true;

  /// Add cloud bookkeeping fields. Any Firestore [Timestamp] values that may
  /// have been set by the server get normalized to ISO strings so the
  /// model's `fromMap` (which expects ISO strings) keeps working after a
  /// round-trip.
  static Map<String, dynamic> _stamp(
    Map<String, dynamic> raw, {
    required String deviceId,
    required bool deleted,
  }) {
    return {
      ...raw,
      CloudFieldKeys.deleted: deleted,
      CloudFieldKeys.lastWriterDeviceId: deviceId,
      CloudFieldKeys.cloudUpdatedAt: FieldValue.serverTimestamp(),
    };
  }

  static T? _safeDecode<T>(
    Map<String, dynamic> doc,
    T Function(Map<String, dynamic>) build,
  ) {
    try {
      final clean = _normalizeFromFirestore(doc);
      return build(clean);
    } catch (_) {
      return null;
    }
  }

  /// Strip cloud bookkeeping fields and convert any Firestore-typed values
  /// (Timestamps) back into JSON-friendly forms expected by the model
  /// `fromMap` factories.
  static Map<String, dynamic> _normalizeFromFirestore(
    Map<String, dynamic> doc,
  ) {
    final out = <String, dynamic>{};
    doc.forEach((key, value) {
      if (key == CloudFieldKeys.deleted ||
          key == CloudFieldKeys.cloudUpdatedAt ||
          key == CloudFieldKeys.lastWriterDeviceId) {
        return;
      }
      out[key] = _unwrapValue(value);
    });
    return out;
  }

  static dynamic _unwrapValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is List) {
      return value.map(_unwrapValue).toList();
    }
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) {
        out[k.toString()] = _unwrapValue(v);
      });
      return out;
    }
    return value;
  }
}
