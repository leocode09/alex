import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const String _pinKey = 'user_pin';
  static const String _pinSetKey = 'pin_is_set';
  static const String _pinPreferencesKey = 'pin_preferences';
  static bool _sessionVerified = false;

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
    final preferences = {
      'login': requireOnLogin,
      'settings': requireOnSettings,
      'dashboard': requireOnDashboard,
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
    };

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
      return decoded.map((key, value) => MapEntry(key, value as bool));
    } catch (e) {
      return _getDefaultPreferences();
    }
  }

  Map<String, bool> _getDefaultPreferences() {
    return {
      'login': true,
      'settings': false,
      'dashboard': false,
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
  }

  // Auth & General
  Future<bool> isPinRequiredForLogin() async {
    final prefs = await _getPreferencesMap();
    return prefs['login'] ?? true;
  }

  Future<bool> isPinRequiredForSettings() async {
    final prefs = await _getPreferencesMap();
    return prefs['settings'] ?? false;
  }

  Future<bool> isPinRequiredForDashboard() async {
    final prefs = await _getPreferencesMap();
    return prefs['dashboard'] ?? false;
  }

  // Products
  Future<bool> isPinRequiredForAddProduct() async {
    final prefs = await _getPreferencesMap();
    return prefs['addProduct'] ?? false;
  }

  Future<bool> isPinRequiredForEditProduct() async {
    final prefs = await _getPreferencesMap();
    return prefs['editProduct'] ?? false;
  }

  Future<bool> isPinRequiredForDeleteProduct() async {
    final prefs = await _getPreferencesMap();
    return prefs['deleteProduct'] ?? false;
  }

  Future<bool> isPinRequiredForViewProductDetails() async {
    final prefs = await _getPreferencesMap();
    return prefs['viewProductDetails'] ?? false;
  }

  Future<bool> isPinRequiredForScanBarcode() async {
    final prefs = await _getPreferencesMap();
    return prefs['scanBarcode'] ?? false;
  }

  Future<bool> isPinRequiredForAdjustStock() async {
    final prefs = await _getPreferencesMap();
    return prefs['adjustStock'] ?? false;
  }

  // Sales
  Future<bool> isPinRequiredForCreateSale() async {
    final prefs = await _getPreferencesMap();
    return prefs['createSale'] ?? false;
  }

  Future<bool> isPinRequiredForViewSalesHistory() async {
    final prefs = await _getPreferencesMap();
    return prefs['viewSalesHistory'] ?? false;
  }

  Future<bool> isPinRequiredForEditReceipt() async {
    final prefs = await _getPreferencesMap();
    return prefs['editReceipt'] ?? false;
  }

  Future<bool> isPinRequiredForDeleteReceipt() async {
    final prefs = await _getPreferencesMap();
    return prefs['deleteReceipt'] ?? false;
  }

  Future<bool> isPinRequiredForApplyDiscount() async {
    final prefs = await _getPreferencesMap();
    return prefs['applyDiscount'] ?? false;
  }

  Future<bool> isPinRequiredForIssueRefund() async {
    final prefs = await _getPreferencesMap();
    return prefs['issueRefund'] ?? false;
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
    return prefs['reports'] ?? false;
  }

  Future<bool> isPinRequiredForViewFinancialReports() async {
    final prefs = await _getPreferencesMap();
    return prefs['viewFinancialReports'] ?? false;
  }

  Future<bool> isPinRequiredForViewInventoryReports() async {
    final prefs = await _getPreferencesMap();
    return prefs['viewInventoryReports'] ?? false;
  }

  Future<bool> isPinRequiredForExportReports() async {
    final prefs = await _getPreferencesMap();
    return prefs['exportReports'] ?? false;
  }

  // System & Data Management
  Future<bool> isPinRequiredForHardwareSetup() async {
    final prefs = await _getPreferencesMap();
    return prefs['hardwareSetup'] ?? false;
  }

  Future<bool> isPinRequiredForDataSync() async {
    final prefs = await _getPreferencesMap();
    return prefs['dataSync'] ?? false;
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
    await prefs.setString(_pinPreferencesKey, jsonEncode(preferences));
  }

  Future<void> clearPin() async {
    _sessionVerified = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setBool(_pinSetKey, false);
    await prefs.remove(_pinPreferencesKey);
  }
}
