/// Central place for Firestore collection / document paths.
///
/// Data is partitioned under `/shops/{shopId}` so multiple isolated shops
/// can live in the same Firebase project.
class FirestorePaths {
  const FirestorePaths._();

  static const String shopsCollection = 'shops';

  /// Top-level collection listing every device install that has booted
  /// the app. Doc id is the per-install UUID. Used by the super admin.
  static const String devicesCollection = 'devices';

  /// Top-level allowlist. Presence of a doc with id == uid grants
  /// super-admin privileges on read/write rules.
  static const String adminsCollection = 'admins';

  /// Per-device / per-shop daily usage counters.
  static const String usageDailySubcollection = 'usageDaily';

  // Subcollection names under /shops/{shopId}
  static const String membersSubcollection = 'members';
  static const String productsSubcollection = 'products';
  static const String categoriesSubcollection = 'categories';
  static const String customersSubcollection = 'customers';
  static const String employeesSubcollection = 'employees';
  static const String expensesSubcollection = 'expenses';
  static const String salesSubcollection = 'sales';
  static const String storesSubcollection = 'stores';
  static const String moneyAccountsSubcollection = 'moneyAccounts';
  static const String moneyHistorySubcollection = 'moneyHistory';
  static const String inventoryMovementsSubcollection = 'inventoryMovements';
  static const String customerCreditEntriesSubcollection =
      'customerCreditEntries';
  static const String settingsSubcollection = 'settings';

  /// Collections that can receive live snapshot listeners for two-way sync.
  static const List<String> syncedEntityCollections = <String>[
    productsSubcollection,
    categoriesSubcollection,
    customersSubcollection,
    employeesSubcollection,
    expensesSubcollection,
    salesSubcollection,
    storesSubcollection,
    moneyAccountsSubcollection,
    moneyHistorySubcollection,
    inventoryMovementsSubcollection,
    customerCreditEntriesSubcollection,
  ];
}

/// Entity types that support soft-delete via `{deleted: true}` on the
/// remote doc (mirrors the existing `deleted_product_ids` tombstone pattern
/// used by LAN sync).
class SoftDeletable {
  const SoftDeletable._();

  static const Set<String> collections = {
    FirestorePaths.productsSubcollection,
    FirestorePaths.categoriesSubcollection,
    FirestorePaths.customersSubcollection,
    FirestorePaths.employeesSubcollection,
    FirestorePaths.expensesSubcollection,
    FirestorePaths.storesSubcollection,
    FirestorePaths.moneyAccountsSubcollection,
    FirestorePaths.customerCreditEntriesSubcollection,
  };
}
