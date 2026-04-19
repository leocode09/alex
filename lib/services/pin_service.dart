import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/license_policy.dart';
import 'admin/license_service.dart';

class PinService {
  static const String _pinKey = 'user_pin';
  static const String _pinSetKey = 'pin_is_set';
  static const String _pinPreferencesKey = 'pin_preferences';
  static const String _visibilityPrefix = 'visible_';
  static bool _sessionVerified = false;

  /// Mapping from a PIN preference key (as used in SharedPreferences
  /// and the PIN preferences screen) to the [FeatureKey] the super
  /// admin can force behind a PIN. A missing entry means the admin
  /// cannot force PIN for that action; the device's local preference
  /// is used verbatim.
  static const Map<String, FeatureKey> _pinKeyToFeature = {
    // Sales
    'createSale': FeatureKey.sales,
    'viewSalesHistory': FeatureKey.sales,
    'editReceipt': FeatureKey.sales,
    'deleteReceipt': FeatureKey.sales,
    'applyDiscount': FeatureKey.sales,
    'issueRefund': FeatureKey.sales,
    // Products / inventory
    'addProduct': FeatureKey.inventoryEdit,
    'editProduct': FeatureKey.inventoryEdit,
    'deleteProduct': FeatureKey.inventoryEdit,
    'viewProductDetails': FeatureKey.inventoryEdit,
    'adjustStock': FeatureKey.inventoryEdit,
    'scanBarcode': FeatureKey.inventoryEdit,
    // Reports
    'reports': FeatureKey.reports,
    'viewFinancialReports': FeatureKey.reports,
    'viewInventoryReports': FeatureKey.reports,
    'exportReports': FeatureKey.reports,
    // Sync
    'dataSync': FeatureKey.cloudSync,
  };

  static String visiblePreferenceKey(String preferenceKey) =>
      '$_visibilityPrefix$preferenceKey';

  /// Returns the final "PIN required" decision, honouring both the
  /// device's local preference and any admin-forced PIN for the
  /// feature this key belongs to.
  bool _applyPolicyOverride(String prefKey, bool localRequired) {
    if (localRequired) {
      return true;
    }
    final feature = _pinKeyToFeature[prefKey];
    if (feature == null) {
      return false;
    }
    return LicenseService().current.isPinForced(feature);
  }

  Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinSetKey) ?? false;
  }

  Future<void> setPin(
    String pin, {
    // Auth & General
    bool requireOnLogin = true,
    bool requireOnSettings = false,
    bool requireOnDashboard = false,

    // Money
    bool requireOnAddMoneyAccount = false,
    bool requireOnEditMoneyAccount = false,
    bool requireOnDeleteMoneyAccount = false,
    bool requireOnAddMoney = false,
    bool requireOnRemoveMoney = false,
    bool requireOnViewMoneyHistory = false,
    bool requireOnEditMoneyHistory = false,

    // Products
    bool requireOnAddProduct = false,
    bool requireOnEditProduct = false,
    bool requireOnDeleteProduct = false,
    bool requireOnViewProductDetails = false,
    bool requireOnScanBarcode = false,
    bool requireOnAdjustStock = false,

    // Sales
    bool requireOnCreateSale = false,
    bool requireOnViewSalesHistory = false,
    bool requireOnEditReceipt = false,
    bool requireOnDeleteReceipt = false,
    bool requireOnApplyDiscount = false,
    bool requireOnIssueRefund = false,

    // Categories
    bool requireOnAddCategory = false,
    bool requireOnEditCategory = false,
    bool requireOnDeleteCategory = false,
    bool requireOnViewCategories = false,

    // Customers
    bool requireOnViewCustomers = false,
    bool requireOnAddCustomer = false,
    bool requireOnEditCustomer = false,
    bool requireOnDeleteCustomer = false,

    // Employees
    bool requireOnViewEmployees = false,
    bool requireOnAddEmployee = false,
    bool requireOnEditEmployee = false,
    bool requireOnDeleteEmployee = false,

    // Stores
    bool requireOnViewStores = false,
    bool requireOnAddStore = false,
    bool requireOnEditStore = false,
    bool requireOnDeleteStore = false,

    // Reports & Analytics
    bool requireOnReports = false,
    bool requireOnViewFinancialReports = false,
    bool requireOnViewInventoryReports = false,
    bool requireOnExportReports = false,

    // System & Data Management
    bool requireOnHardwareSetup = false,
    bool requireOnDataSync = false,
    bool requireOnClearAllData = true,
    bool requireOnManagePromotions = false,
    bool requireOnViewNotifications = false,

    // Settings Subsections
    bool requireOnTaxSettings = false,
    bool requireOnReceiptSettings = false,
    bool requireOnChangePin = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    await prefs.setBool(_pinSetKey, true);

    // Store all preferences in a single JSON key
    final preferences = _withDefaultPreferences({
      'login': requireOnLogin,
      'settings': requireOnSettings,
      'dashboard': requireOnDashboard,
      'addMoneyAccount': requireOnAddMoneyAccount,
      'editMoneyAccount': requireOnEditMoneyAccount,
      'deleteMoneyAccount': requireOnDeleteMoneyAccount,
      'addMoney': requireOnAddMoney,
      'removeMoney': requireOnRemoveMoney,
      'viewMoneyHistory': requireOnViewMoneyHistory,
      'editMoneyHistory': requireOnEditMoneyHistory,
      'addProduct': requireOnAddProduct,
      'editProduct': requireOnEditProduct,
      'deleteProduct': requireOnDeleteProduct,
      'viewProductDetails': requireOnViewProductDetails,
      'scanBarcode': requireOnScanBarcode,
      'adjustStock': requireOnAdjustStock,
      'createSale': requireOnCreateSale,
      'viewSalesHistory': requireOnViewSalesHistory,
      'editReceipt': requireOnEditReceipt,
      'deleteReceipt': requireOnDeleteReceipt,
      'applyDiscount': requireOnApplyDiscount,
      'issueRefund': requireOnIssueRefund,
      'addCategory': requireOnAddCategory,
      'editCategory': requireOnEditCategory,
      'deleteCategory': requireOnDeleteCategory,
      'viewCategories': requireOnViewCategories,
      'viewCustomers': requireOnViewCustomers,
      'addCustomer': requireOnAddCustomer,
      'editCustomer': requireOnEditCustomer,
      'deleteCustomer': requireOnDeleteCustomer,
      'viewEmployees': requireOnViewEmployees,
      'addEmployee': requireOnAddEmployee,
      'editEmployee': requireOnEditEmployee,
      'deleteEmployee': requireOnDeleteEmployee,
      'viewStores': requireOnViewStores,
      'addStore': requireOnAddStore,
      'editStore': requireOnEditStore,
      'deleteStore': requireOnDeleteStore,
      'reports': requireOnReports,
      'viewFinancialReports': requireOnViewFinancialReports,
      'viewInventoryReports': requireOnViewInventoryReports,
      'exportReports': requireOnExportReports,
      'hardwareSetup': requireOnHardwareSetup,
      'dataSync': requireOnDataSync,
      'clearAllData': requireOnClearAllData,
      'managePromotions': requireOnManagePromotions,
      'viewNotifications': requireOnViewNotifications,
      'taxSettings': requireOnTaxSettings,
      'receiptSettings': requireOnReceiptSettings,
      'changePin': requireOnChangePin,
    });

    await prefs.setString(_pinPreferencesKey, jsonEncode(preferences));
  }

  Future<void> updatePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    await prefs.setBool(_pinSetKey, true);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_pinKey);
    final isValid = storedPin == pin;
    if (isValid) {
      _sessionVerified = true;
    }
    return isValid;
  }

  bool isSessionVerified() => _sessionVerified;

  void clearSessionVerified() {
    _sessionVerified = false;
  }

  // Helper method to get preferences map
  Future<Map<String, bool>> _getPreferencesMap() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsString = prefs.getString(_pinPreferencesKey);

    if (prefsString == null) {
      return _getDefaultPreferences();
    }

    try {
      final decoded = jsonDecode(prefsString) as Map<String, dynamic>;
      final sanitized = <String, bool>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is bool) {
          sanitized[entry.key] = value;
        }
      }
      return _withDefaultPreferences(sanitized);
    } catch (e) {
      return _getDefaultPreferences();
    }
  }

  Map<String, bool> _withDefaultPreferences(Map<String, bool> preferences) {
    return {
      ..._getDefaultPreferences(),
      ...preferences,
    };
  }

  Map<String, bool> _getDefaultPreferences() {
    final defaults = <String, bool>{
      'login': true,
      'settings': false,
      'dashboard': false,
      'addMoneyAccount': false,
      'editMoneyAccount': false,
      'deleteMoneyAccount': false,
      'addMoney': false,
      'removeMoney': false,
      'viewMoneyHistory': false,
      'editMoneyHistory': false,
      'addProduct': false,
      'editProduct': false,
      'deleteProduct': false,
      'viewProductDetails': false,
      'scanBarcode': false,
      'adjustStock': false,
      'createSale': false,
      'viewSalesHistory': false,
      'editReceipt': false,
      'deleteReceipt': false,
      'applyDiscount': false,
      'issueRefund': false,
      'addCategory': false,
      'editCategory': false,
      'deleteCategory': false,
      'viewCategories': false,
      'viewCustomers': false,
      'addCustomer': false,
      'editCustomer': false,
      'deleteCustomer': false,
      'viewEmployees': false,
      'addEmployee': false,
      'editEmployee': false,
      'deleteEmployee': false,
      'viewStores': false,
      'addStore': false,
      'editStore': false,
      'deleteStore': false,
      'reports': false,
      'viewFinancialReports': false,
      'viewInventoryReports': false,
      'exportReports': false,
      'hardwareSetup': false,
      'dataSync': false,
      'clearAllData': true,
      'managePromotions': false,
      'viewNotifications': false,
      'taxSettings': false,
      'receiptSettings': false,
      'changePin': true,
    };

    final featureKeys = defaults.keys.toList();
    for (final key in featureKeys) {
      defaults[visiblePreferenceKey(key)] = true;
    }

    return defaults;
  }

  Future<bool> isFeatureVisible(
    String featureKey, {
    bool defaultValue = true,
  }) async {
    final prefs = await _getPreferencesMap();
    return prefs[visiblePreferenceKey(featureKey)] ?? defaultValue;
  }

  // Auth & General
  Future<bool> isPinRequiredForLogin() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('login', prefs['login'] ?? true);
  }

  Future<bool> isPinRequiredForSettings() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('settings', prefs['settings'] ?? false);
  }

  Future<bool> isPinRequiredForDashboard() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('dashboard', prefs['dashboard'] ?? false);
  }

  // Money
  Future<bool> isPinRequiredForAddMoneyAccount() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'addMoneyAccount', prefs['addMoneyAccount'] ?? false);
  }

  Future<bool> isPinRequiredForEditMoneyAccount() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'editMoneyAccount', prefs['editMoneyAccount'] ?? false);
  }

  Future<bool> isPinRequiredForDeleteMoneyAccount() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'deleteMoneyAccount', prefs['deleteMoneyAccount'] ?? false);
  }

  Future<bool> isPinRequiredForAddMoney() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('addMoney', prefs['addMoney'] ?? false);
  }

  Future<bool> isPinRequiredForRemoveMoney() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('removeMoney', prefs['removeMoney'] ?? false);
  }

  Future<bool> isPinRequiredForViewMoneyHistory() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'viewMoneyHistory', prefs['viewMoneyHistory'] ?? false);
  }

  Future<bool> isPinRequiredForEditMoneyHistory() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'editMoneyHistory', prefs['editMoneyHistory'] ?? false);
  }

  // Products
  Future<bool> isPinRequiredForAddProduct() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('addProduct', prefs['addProduct'] ?? false);
  }

  Future<bool> isPinRequiredForEditProduct() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('editProduct', prefs['editProduct'] ?? false);
  }

  Future<bool> isPinRequiredForDeleteProduct() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'deleteProduct', prefs['deleteProduct'] ?? false);
  }

  Future<bool> isPinRequiredForViewProductDetails() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'viewProductDetails', prefs['viewProductDetails'] ?? false);
  }

  Future<bool> isPinRequiredForScanBarcode() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('scanBarcode', prefs['scanBarcode'] ?? false);
  }

  Future<bool> isPinRequiredForAdjustStock() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('adjustStock', prefs['adjustStock'] ?? false);
  }

  // Sales
  Future<bool> isPinRequiredForCreateSale() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('createSale', prefs['createSale'] ?? false);
  }

  Future<bool> isPinRequiredForViewSalesHistory() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'viewSalesHistory', prefs['viewSalesHistory'] ?? false);
  }

  Future<bool> isPinRequiredForEditReceipt() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('editReceipt', prefs['editReceipt'] ?? false);
  }

  Future<bool> isPinRequiredForDeleteReceipt() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'deleteReceipt', prefs['deleteReceipt'] ?? false);
  }

  Future<bool> isPinRequiredForApplyDiscount() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'applyDiscount', prefs['applyDiscount'] ?? false);
  }

  Future<bool> isPinRequiredForIssueRefund() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('issueRefund', prefs['issueRefund'] ?? false);
  }

  // Categories
  Future<bool> isPinRequiredForAddCategory() async {
    final prefs = await _getPreferencesMap();
    return prefs['addCategory'] ?? false;
  }

  Future<bool> isPinRequiredForEditCategory() async {
    final prefs = await _getPreferencesMap();
    return prefs['editCategory'] ?? false;
  }

  Future<bool> isPinRequiredForDeleteCategory() async {
    final prefs = await _getPreferencesMap();
    return prefs['deleteCategory'] ?? false;
  }

  Future<bool> isPinRequiredForViewCategories() async {
    final prefs = await _getPreferencesMap();
    return prefs['viewCategories'] ?? false;
  }

  // Customers
  Future<bool> isPinRequiredForViewCustomers() async {
    final prefs = await _getPreferencesMap();
    return prefs['viewCustomers'] ?? false;
  }

  Future<bool> isPinRequiredForAddCustomer() async {
    final prefs = await _getPreferencesMap();
    return prefs['addCustomer'] ?? false;
  }

  Future<bool> isPinRequiredForEditCustomer() async {
    final prefs = await _getPreferencesMap();
    return prefs['editCustomer'] ?? false;
  }

  Future<bool> isPinRequiredForDeleteCustomer() async {
    final prefs = await _getPreferencesMap();
    return prefs['deleteCustomer'] ?? false;
  }

  // Employees
  Future<bool> isPinRequiredForViewEmployees() async {
    final prefs = await _getPreferencesMap();
    return prefs['viewEmployees'] ?? false;
  }

  Future<bool> isPinRequiredForAddEmployee() async {
    final prefs = await _getPreferencesMap();
    return prefs['addEmployee'] ?? false;
  }

  Future<bool> isPinRequiredForEditEmployee() async {
    final prefs = await _getPreferencesMap();
    return prefs['editEmployee'] ?? false;
  }

  Future<bool> isPinRequiredForDeleteEmployee() async {
    final prefs = await _getPreferencesMap();
    return prefs['deleteEmployee'] ?? false;
  }

  // Stores
  Future<bool> isPinRequiredForViewStores() async {
    final prefs = await _getPreferencesMap();
    return prefs['viewStores'] ?? false;
  }

  Future<bool> isPinRequiredForAddStore() async {
    final prefs = await _getPreferencesMap();
    return prefs['addStore'] ?? false;
  }

  Future<bool> isPinRequiredForEditStore() async {
    final prefs = await _getPreferencesMap();
    return prefs['editStore'] ?? false;
  }

  Future<bool> isPinRequiredForDeleteStore() async {
    final prefs = await _getPreferencesMap();
    return prefs['deleteStore'] ?? false;
  }

  // Reports & Analytics
  Future<bool> isPinRequiredForReports() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('reports', prefs['reports'] ?? false);
  }

  Future<bool> isPinRequiredForViewFinancialReports() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'viewFinancialReports', prefs['viewFinancialReports'] ?? false);
  }

  Future<bool> isPinRequiredForViewInventoryReports() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'viewInventoryReports', prefs['viewInventoryReports'] ?? false);
  }

  Future<bool> isPinRequiredForExportReports() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'exportReports', prefs['exportReports'] ?? false);
  }

  // System & Data Management
  Future<bool> isPinRequiredForHardwareSetup() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride(
        'hardwareSetup', prefs['hardwareSetup'] ?? false);
  }

  Future<bool> isPinRequiredForDataSync() async {
    final prefs = await _getPreferencesMap();
    return _applyPolicyOverride('dataSync', prefs['dataSync'] ?? false);
  }

  Future<bool> isPinRequiredForClearAllData() async {
    final prefs = await _getPreferencesMap();
    return prefs['clearAllData'] ?? true;
  }

  Future<bool> isPinRequiredForManagePromotions() async {
    final prefs = await _getPreferencesMap();
    return prefs['managePromotions'] ?? false;
  }

  Future<bool> isPinRequiredForViewNotifications() async {
    final prefs = await _getPreferencesMap();
    return prefs['viewNotifications'] ?? false;
  }

  // Settings Subsections
  Future<bool> isPinRequiredForTaxSettings() async {
    final prefs = await _getPreferencesMap();
    return prefs['taxSettings'] ?? false;
  }

  Future<bool> isPinRequiredForReceiptSettings() async {
    final prefs = await _getPreferencesMap();
    return prefs['receiptSettings'] ?? false;
  }

  Future<bool> isPinRequiredForChangePin() async {
    final prefs = await _getPreferencesMap();
    return prefs['changePin'] ?? true;
  }

  Future<Map<String, bool>> getPinPreferences() async {
    return await _getPreferencesMap();
  }

  Future<void> updatePinPreferences(Map<String, bool> preferences) async {
    final prefs = await SharedPreferences.getInstance();
    final mergedPreferences = _withDefaultPreferences(preferences);
    await prefs.setString(_pinPreferencesKey, jsonEncode(mergedPreferences));
  }

  Future<void> clearPin() async {
    _sessionVerified = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setBool(_pinSetKey, false);
    await prefs.remove(_pinPreferencesKey);
  }
}
