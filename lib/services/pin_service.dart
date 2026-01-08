import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const String _pinKey = 'user_pin';
  static const String _pinSetKey = 'pin_is_set';
  
  // Auth & General
  static const String _pinOnLoginKey = 'pin_on_login';
  static const String _pinOnSettingsKey = 'pin_on_settings';
  static const String _pinOnDashboardKey = 'pin_on_dashboard';
  
  // Products
  static const String _pinOnAddProductKey = 'pin_on_add_product';
  static const String _pinOnEditProductKey = 'pin_on_edit_product';
  static const String _pinOnDeleteProductKey = 'pin_on_delete_product';
  static const String _pinOnViewProductDetailsKey = 'pin_on_view_product_details';
  static const String _pinOnScanBarcodeKey = 'pin_on_scan_barcode';
  static const String _pinOnAdjustStockKey = 'pin_on_adjust_stock';
  
  // Sales
  static const String _pinOnCreateSaleKey = 'pin_on_create_sale';
  static const String _pinOnViewSalesHistoryKey = 'pin_on_view_sales_history';
  static const String _pinOnEditReceiptKey = 'pin_on_edit_receipt';
  static const String _pinOnDeleteReceiptKey = 'pin_on_delete_receipt';
  static const String _pinOnApplyDiscountKey = 'pin_on_apply_discount';
  static const String _pinOnIssueRefundKey = 'pin_on_issue_refund';
  
  // Categories
  static const String _pinOnAddCategoryKey = 'pin_on_add_category';
  static const String _pinOnEditCategoryKey = 'pin_on_edit_category';
  static const String _pinOnDeleteCategoryKey = 'pin_on_delete_category';
  static const String _pinOnViewCategoriesKey = 'pin_on_view_categories';
  
  // Customers
  static const String _pinOnViewCustomersKey = 'pin_on_view_customers';
  static const String _pinOnAddCustomerKey = 'pin_on_add_customer';
  static const String _pinOnEditCustomerKey = 'pin_on_edit_customer';
  static const String _pinOnDeleteCustomerKey = 'pin_on_delete_customer';
  
  // Employees
  static const String _pinOnViewEmployeesKey = 'pin_on_view_employees';
  static const String _pinOnAddEmployeeKey = 'pin_on_add_employee';
  static const String _pinOnEditEmployeeKey = 'pin_on_edit_employee';
  static const String _pinOnDeleteEmployeeKey = 'pin_on_delete_employee';
  
  // Stores
  static const String _pinOnViewStoresKey = 'pin_on_view_stores';
  static const String _pinOnAddStoreKey = 'pin_on_add_store';
  static const String _pinOnEditStoreKey = 'pin_on_edit_store';
  static const String _pinOnDeleteStoreKey = 'pin_on_delete_store';
  
  // Reports & Analytics
  static const String _pinOnReportsKey = 'pin_on_reports';
  static const String _pinOnViewFinancialReportsKey = 'pin_on_view_financial_reports';
  static const String _pinOnViewInventoryReportsKey = 'pin_on_view_inventory_reports';
  static const String _pinOnExportReportsKey = 'pin_on_export_reports';
  
  // System & Data Management
  static const String _pinOnHardwareSetupKey = 'pin_on_hardware_setup';
  static const String _pinOnDataSyncKey = 'pin_on_data_sync';
  static const String _pinOnClearAllDataKey = 'pin_on_clear_all_data';
  static const String _pinOnManagePromotionsKey = 'pin_on_manage_promotions';
  static const String _pinOnViewNotificationsKey = 'pin_on_view_notifications';
  
  // Settings Subsections
  static const String _pinOnTaxSettingsKey = 'pin_on_tax_settings';
  static const String _pinOnReceiptSettingsKey = 'pin_on_receipt_settings';
  static const String _pinOnChangePinKey = 'pin_on_change_pin';

  Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinSetKey) ?? false;
  }

  Future<void> setPin(String pin, {
    bool requireOnLogin = true,
    bool requireOnAddProduct = false,
    bool requireOnEditProduct = false,
    bool requireOnDeleteProduct = false,
    bool requireOnSettings = false,
    bool requireOnReports = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    await prefs.setBool(_pinSetKey, true);
    await prefs.setBool(_pinOnLoginKey, requireOnLogin);
    await prefs.setBool(_pinOnAddProductKey, requireOnAddProduct);
    await prefs.setBool(_pinOnEditProductKey, requireOnEditProduct);
    await prefs.setBool(_pinOnDeleteProductKey, requireOnDeleteProduct);
    await prefs.setBool(_pinOnSettingsKey, requireOnSettings);
    await prefs.setBool(_pinOnReportsKey, requireOnReports);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_pinKey);
    return storedPin == pin;
  }

  Future<bool> isPinRequiredForLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnLoginKey) ?? true;
  }

  Future<bool> isPinRequiredForAddProduct() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnAddProductKey) ?? false;
  }

  Future<bool> isPinRequiredForEditProduct() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnEditProductKey) ?? false;
  }

  Future<bool> isPinRequiredForDeleteProduct() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnDeleteProductKey) ?? false;
  }

  Future<bool> isPinRequiredForSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnSettingsKey) ?? false;
  }

  Future<bool> isPinRequiredForReports() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnReportsKey) ?? false;
  }

  Future<Map<String, bool>> getPinPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'login': prefs.getBool(_pinOnLoginKey) ?? true,
      'addProduct': prefs.getBool(_pinOnAddProductKey) ?? false,
      'editProduct': prefs.getBool(_pinOnEditProductKey) ?? false,
      'deleteProduct': prefs.getBool(_pinOnDeleteProductKey) ?? false,
      'settings': prefs.getBool(_pinOnSettingsKey) ?? false,
      'reports': prefs.getBool(_pinOnReportsKey) ?? false,
    };
  }

  Future<void> updatePinPreferences({
    required bool requireOnLogin,
    required bool requireOnAddProduct,
    required bool requireOnEditProduct,
    required bool requireOnDeleteProduct,
    required bool requireOnSettings,
    required bool requireOnReports,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pinOnLoginKey, requireOnLogin);
    await prefs.setBool(_pinOnAddProductKey, requireOnAddProduct);
    await prefs.setBool(_pinOnEditProductKey, requireOnEditProduct);
    await prefs.setBool(_pinOnDeleteProductKey, requireOnDeleteProduct);
    await prefs.setBool(_pinOnSettingsKey, requireOnSettings);
    await prefs.setBool(_pinOnReportsKey, requireOnReports);
  }

  Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setBool(_pinSetKey, false);
    await prefs.remove(_pinOnLoginKey);
    await prefs.remove(_pinOnAddProductKey);
    await prefs.remove(_pinOnEditProductKey);
    await prefs.remove(_pinOnDeleteProductKey);
    await prefs.remove(_pinOnSettingsKey);
    await prefs.remove(_pinOnReportsKey);
  }
}
