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
    
    // Auth & General
    await prefs.setBool(_pinOnLoginKey, requireOnLogin);
    await prefs.setBool(_pinOnSettingsKey, requireOnSettings);
    await prefs.setBool(_pinOnDashboardKey, requireOnDashboard);
    
    // Products
    await prefs.setBool(_pinOnAddProductKey, requireOnAddProduct);
    await prefs.setBool(_pinOnEditProductKey, requireOnEditProduct);
    await prefs.setBool(_pinOnDeleteProductKey, requireOnDeleteProduct);
    await prefs.setBool(_pinOnViewProductDetailsKey, requireOnViewProductDetails);
    await prefs.setBool(_pinOnScanBarcodeKey, requireOnScanBarcode);
    await prefs.setBool(_pinOnAdjustStockKey, requireOnAdjustStock);
    
    // Sales
    await prefs.setBool(_pinOnCreateSaleKey, requireOnCreateSale);
    await prefs.setBool(_pinOnViewSalesHistoryKey, requireOnViewSalesHistory);
    await prefs.setBool(_pinOnEditReceiptKey, requireOnEditReceipt);
    await prefs.setBool(_pinOnDeleteReceiptKey, requireOnDeleteReceipt);
    await prefs.setBool(_pinOnApplyDiscountKey, requireOnApplyDiscount);
    await prefs.setBool(_pinOnIssueRefundKey, requireOnIssueRefund);
    
    // Categories
    await prefs.setBool(_pinOnAddCategoryKey, requireOnAddCategory);
    await prefs.setBool(_pinOnEditCategoryKey, requireOnEditCategory);
    await prefs.setBool(_pinOnDeleteCategoryKey, requireOnDeleteCategory);
    await prefs.setBool(_pinOnViewCategoriesKey, requireOnViewCategories);
    
    // Customers
    await prefs.setBool(_pinOnViewCustomersKey, requireOnViewCustomers);
    await prefs.setBool(_pinOnAddCustomerKey, requireOnAddCustomer);
    await prefs.setBool(_pinOnEditCustomerKey, requireOnEditCustomer);
    await prefs.setBool(_pinOnDeleteCustomerKey, requireOnDeleteCustomer);
    
    // Employees
    await prefs.setBool(_pinOnViewEmployeesKey, requireOnViewEmployees);
    await prefs.setBool(_pinOnAddEmployeeKey, requireOnAddEmployee);
    await prefs.setBool(_pinOnEditEmployeeKey, requireOnEditEmployee);
    await prefs.setBool(_pinOnDeleteEmployeeKey, requireOnDeleteEmployee);
    
    // Stores
    await prefs.setBool(_pinOnViewStoresKey, requireOnViewStores);
    await prefs.setBool(_pinOnAddStoreKey, requireOnAddStore);
    await prefs.setBool(_pinOnEditStoreKey, requireOnEditStore);
    await prefs.setBool(_pinOnDeleteStoreKey, requireOnDeleteStore);
    
    // Reports & Analytics
    await prefs.setBool(_pinOnReportsKey, requireOnReports);
    await prefs.setBool(_pinOnViewFinancialReportsKey, requireOnViewFinancialReports);
    await prefs.setBool(_pinOnViewInventoryReportsKey, requireOnViewInventoryReports);
    await prefs.setBool(_pinOnExportReportsKey, requireOnExportReports);
    
    // System & Data Management
    await prefs.setBool(_pinOnHardwareSetupKey, requireOnHardwareSetup);
    await prefs.setBool(_pinOnDataSyncKey, requireOnDataSync);
    await prefs.setBool(_pinOnClearAllDataKey, requireOnClearAllData);
    await prefs.setBool(_pinOnManagePromotionsKey, requireOnManagePromotions);
    await prefs.setBool(_pinOnViewNotificationsKey, requireOnViewNotifications);
    
    // Settings Subsections
    await prefs.setBool(_pinOnTaxSettingsKey, requireOnTaxSettings);
    await prefs.setBool(_pinOnReceiptSettingsKey, requireOnReceiptSettings);
    await prefs.setBool(_pinOnChangePinKey, requireOnChangePin);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_pinKey);
    return storedPin == pin;
  }

  // Auth & General
  Future<bool> isPinRequiredForLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnLoginKey) ?? true;
  }

  Future<bool> isPinRequiredForSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnSettingsKey) ?? false;
  }

  Future<bool> isPinRequiredForDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnDashboardKey) ?? false;
  }

  // Products
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

  Future<bool> isPinRequiredForViewProductDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnViewProductDetailsKey) ?? false;
  }

  Future<bool> isPinRequiredForScanBarcode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnScanBarcodeKey) ?? false;
  }

  Future<bool> isPinRequiredForAdjustStock() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnAdjustStockKey) ?? false;
  }

  // Sales
  Future<bool> isPinRequiredForCreateSale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnCreateSaleKey) ?? false;
  }

  Future<bool> isPinRequiredForViewSalesHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnViewSalesHistoryKey) ?? false;
  }

  Future<bool> isPinRequiredForEditReceipt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnEditReceiptKey) ?? false;
  }

  Future<bool> isPinRequiredForDeleteReceipt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnDeleteReceiptKey) ?? false;
  }

  Future<bool> isPinRequiredForApplyDiscount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnApplyDiscountKey) ?? false;
  }

  Future<bool> isPinRequiredForIssueRefund() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnIssueRefundKey) ?? false;
  }

  // Categories
  Future<bool> isPinRequiredForAddCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnAddCategoryKey) ?? false;
  }

  Future<bool> isPinRequiredForEditCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnEditCategoryKey) ?? false;
  }

  Future<bool> isPinRequiredForDeleteCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnDeleteCategoryKey) ?? false;
  }

  Future<bool> isPinRequiredForViewCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnViewCategoriesKey) ?? false;
  }

  // Customers
  Future<bool> isPinRequiredForViewCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnViewCustomersKey) ?? false;
  }

  Future<bool> isPinRequiredForAddCustomer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnAddCustomerKey) ?? false;
  }

  Future<bool> isPinRequiredForEditCustomer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnEditCustomerKey) ?? false;
  }

  Future<bool> isPinRequiredForDeleteCustomer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnDeleteCustomerKey) ?? false;
  }

  // Employees
  Future<bool> isPinRequiredForViewEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnViewEmployeesKey) ?? false;
  }

  Future<bool> isPinRequiredForAddEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnAddEmployeeKey) ?? false;
  }

  Future<bool> isPinRequiredForEditEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnEditEmployeeKey) ?? false;
  }

  Future<bool> isPinRequiredForDeleteEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnDeleteEmployeeKey) ?? false;
  }

  // Stores
  Future<bool> isPinRequiredForViewStores() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnViewStoresKey) ?? false;
  }

  Future<bool> isPinRequiredForAddStore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnAddStoreKey) ?? false;
  }

  Future<bool> isPinRequiredForEditStore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnEditStoreKey) ?? false;
  }

  Future<bool> isPinRequiredForDeleteStore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnDeleteStoreKey) ?? false;
  }

  // Reports & Analytics
  Future<bool> isPinRequiredForReports() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnReportsKey) ?? false;
  }

  Future<bool> isPinRequiredForViewFinancialReports() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnViewFinancialReportsKey) ?? false;
  }

  Future<bool> isPinRequiredForViewInventoryReports() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnViewInventoryReportsKey) ?? false;
  }

  Future<bool> isPinRequiredForExportReports() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnExportReportsKey) ?? false;
  }

  // System & Data Management
  Future<bool> isPinRequiredForHardwareSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnHardwareSetupKey) ?? false;
  }

  Future<bool> isPinRequiredForDataSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnDataSyncKey) ?? false;
  }

  Future<bool> isPinRequiredForClearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnClearAllDataKey) ?? true;
  }

  Future<bool> isPinRequiredForManagePromotions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnManagePromotionsKey) ?? false;
  }

  Future<bool> isPinRequiredForViewNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnViewNotificationsKey) ?? false;
  }

  // Settings Subsections
  Future<bool> isPinRequiredForTaxSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnTaxSettingsKey) ?? false;
  }

  Future<bool> isPinRequiredForReceiptSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnReceiptSettingsKey) ?? false;
  }

  Future<bool> isPinRequiredForChangePin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnChangePinKey) ?? true;
  }

  Future<Map<String, bool>> getPinPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      // Auth & General
      'login': prefs.getBool(_pinOnLoginKey) ?? true,
      'settings': prefs.getBool(_pinOnSettingsKey) ?? false,
      'dashboard': prefs.getBool(_pinOnDashboardKey) ?? false,
      
      // Products
      'addProduct': prefs.getBool(_pinOnAddProductKey) ?? false,
      'editProduct': prefs.getBool(_pinOnEditProductKey) ?? false,
      'deleteProduct': prefs.getBool(_pinOnDeleteProductKey) ?? false,
      'viewProductDetails': prefs.getBool(_pinOnViewProductDetailsKey) ?? false,
      'scanBarcode': prefs.getBool(_pinOnScanBarcodeKey) ?? false,
      'adjustStock': prefs.getBool(_pinOnAdjustStockKey) ?? false,
      
      // Sales
      'createSale': prefs.getBool(_pinOnCreateSaleKey) ?? false,
      'viewSalesHistory': prefs.getBool(_pinOnViewSalesHistoryKey) ?? false,
      'editReceipt': prefs.getBool(_pinOnEditReceiptKey) ?? false,
      'deleteReceipt': prefs.getBool(_pinOnDeleteReceiptKey) ?? false,
      'applyDiscount': prefs.getBool(_pinOnApplyDiscountKey) ?? false,
      'issueRefund': prefs.getBool(_pinOnIssueRefundKey) ?? false,
      
      // Categories
      'addCategory': prefs.getBool(_pinOnAddCategoryKey) ?? false,
      'editCategory': prefs.getBool(_pinOnEditCategoryKey) ?? false,
      'deleteCategory': prefs.getBool(_pinOnDeleteCategoryKey) ?? false,
      'viewCategories': prefs.getBool(_pinOnViewCategoriesKey) ?? false,
      
      // Customers
      'viewCustomers': prefs.getBool(_pinOnViewCustomersKey) ?? false,
      'addCustomer': prefs.getBool(_pinOnAddCustomerKey) ?? false,
      'editCustomer': prefs.getBool(_pinOnEditCustomerKey) ?? false,
      'deleteCustomer': prefs.getBool(_pinOnDeleteCustomerKey) ?? false,
      
      // Employees
      'viewEmployees': prefs.getBool(_pinOnViewEmployeesKey) ?? false,
      'addEmployee': prefs.getBool(_pinOnAddEmployeeKey) ?? false,
      'editEmployee': prefs.getBool(_pinOnEditEmployeeKey) ?? false,
      'deleteEmployee': prefs.getBool(_pinOnDeleteEmployeeKey) ?? false,
      
      // Stores
      'viewStores': prefs.getBool(_pinOnViewStoresKey) ?? false,
      'addStore': prefs.getBool(_pinOnAddStoreKey) ?? false,
      'editStore': prefs.getBool(_pinOnEditStoreKey) ?? false,
      'deleteStore': prefs.getBool(_pinOnDeleteStoreKey) ?? false,
      
      // Reports
      'reports': prefs.getBool(_pinOnReportsKey) ?? false,
      'viewFinancialReports': prefs.getBool(_pinOnViewFinancialReportsKey) ?? false,
      'viewInventoryReports': prefs.getBool(_pinOnViewInventoryReportsKey) ?? false,
      'exportReports': prefs.getBool(_pinOnExportReportsKey) ?? false,
      
      // System
      'hardwareSetup': prefs.getBool(_pinOnHardwareSetupKey) ?? false,
      'dataSync': prefs.getBool(_pinOnDataSyncKey) ?? false,
      'clearAllData': prefs.getBool(_pinOnClearAllDataKey) ?? true,
      'managePromotions': prefs.getBool(_pinOnManagePromotionsKey) ?? false,
      'viewNotifications': prefs.getBool(_pinOnViewNotificationsKey) ?? false,
      
      // Settings Subsections
      'taxSettings': prefs.getBool(_pinOnTaxSettingsKey) ?? false,
      'receiptSettings': prefs.getBool(_pinOnReceiptSettingsKey) ?? false,
      'changePin': prefs.getBool(_pinOnChangePinKey) ?? true,
    };
  }

  Future<void> updatePinPreferences(Map<String, bool> preferences) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Auth & General
    await prefs.setBool(_pinOnLoginKey, preferences['login'] ?? true);
    await prefs.setBool(_pinOnSettingsKey, preferences['settings'] ?? false);
    await prefs.setBool(_pinOnDashboardKey, preferences['dashboard'] ?? false);
    
    // Products
    await prefs.setBool(_pinOnAddProductKey, preferences['addProduct'] ?? false);
    await prefs.setBool(_pinOnEditProductKey, preferences['editProduct'] ?? false);
    await prefs.setBool(_pinOnDeleteProductKey, preferences['deleteProduct'] ?? false);
    await prefs.setBool(_pinOnViewProductDetailsKey, preferences['viewProductDetails'] ?? false);
    await prefs.setBool(_pinOnScanBarcodeKey, preferences['scanBarcode'] ?? false);
    await prefs.setBool(_pinOnAdjustStockKey, preferences['adjustStock'] ?? false);
    
    // Sales
    await prefs.setBool(_pinOnCreateSaleKey, preferences['createSale'] ?? false);
    await prefs.setBool(_pinOnViewSalesHistoryKey, preferences['viewSalesHistory'] ?? false);
    await prefs.setBool(_pinOnEditReceiptKey, preferences['editReceipt'] ?? false);
    await prefs.setBool(_pinOnDeleteReceiptKey, preferences['deleteReceipt'] ?? false);
    await prefs.setBool(_pinOnApplyDiscountKey, preferences['applyDiscount'] ?? false);
    await prefs.setBool(_pinOnIssueRefundKey, preferences['issueRefund'] ?? false);
    
    // Categories
    await prefs.setBool(_pinOnAddCategoryKey, preferences['addCategory'] ?? false);
    await prefs.setBool(_pinOnEditCategoryKey, preferences['editCategory'] ?? false);
    await prefs.setBool(_pinOnDeleteCategoryKey, preferences['deleteCategory'] ?? false);
    await prefs.setBool(_pinOnViewCategoriesKey, preferences['viewCategories'] ?? false);
    
    // Customers
    await prefs.setBool(_pinOnViewCustomersKey, preferences['viewCustomers'] ?? false);
    await prefs.setBool(_pinOnAddCustomerKey, preferences['addCustomer'] ?? false);
    await prefs.setBool(_pinOnEditCustomerKey, preferences['editCustomer'] ?? false);
    await prefs.setBool(_pinOnDeleteCustomerKey, preferences['deleteCustomer'] ?? false);
    
    // Employees
    await prefs.setBool(_pinOnViewEmployeesKey, preferences['viewEmployees'] ?? false);
    await prefs.setBool(_pinOnAddEmployeeKey, preferences['addEmployee'] ?? false);
    await prefs.setBool(_pinOnEditEmployeeKey, preferences['editEmployee'] ?? false);
    await prefs.setBool(_pinOnDeleteEmployeeKey, preferences['deleteEmployee'] ?? false);
    
    // Stores
    await prefs.setBool(_pinOnViewStoresKey, preferences['viewStores'] ?? false);
    await prefs.setBool(_pinOnAddStoreKey, preferences['addStore'] ?? false);
    await prefs.setBool(_pinOnEditStoreKey, preferences['editStore'] ?? false);
    await prefs.setBool(_pinOnDeleteStoreKey, preferences['deleteStore'] ?? false);
    
    // Reports
    await prefs.setBool(_pinOnReportsKey, preferences['reports'] ?? false);
    await prefs.setBool(_pinOnViewFinancialReportsKey, preferences['viewFinancialReports'] ?? false);
    await prefs.setBool(_pinOnViewInventoryReportsKey, preferences['viewInventoryReports'] ?? false);
    await prefs.setBool(_pinOnExportReportsKey, preferences['exportReports'] ?? false);
    
    // System
    await prefs.setBool(_pinOnHardwareSetupKey, preferences['hardwareSetup'] ?? false);
    await prefs.setBool(_pinOnDataSyncKey, preferences['dataSync'] ?? false);
    await prefs.setBool(_pinOnClearAllDataKey, preferences['clearAllData'] ?? true);
    await prefs.setBool(_pinOnManagePromotionsKey, preferences['managePromotions'] ?? false);
    await prefs.setBool(_pinOnViewNotificationsKey, preferences['viewNotifications'] ?? false);
    
    // Settings Subsections
    await prefs.setBool(_pinOnTaxSettingsKey, preferences['taxSettings'] ?? false);
    await prefs.setBool(_pinOnReceiptSettingsKey, preferences['receiptSettings'] ?? false);
    await prefs.setBool(_pinOnChangePinKey, preferences['changePin'] ?? true);
  }

  Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setBool(_pinSetKey, false);
    
    // Clear all PIN preference keys
    final keys = [
      _pinOnLoginKey, _pinOnSettingsKey, _pinOnDashboardKey,
      _pinOnAddProductKey, _pinOnEditProductKey, _pinOnDeleteProductKey,
      _pinOnViewProductDetailsKey, _pinOnScanBarcodeKey, _pinOnAdjustStockKey,
      _pinOnCreateSaleKey, _pinOnViewSalesHistoryKey, _pinOnEditReceiptKey,
      _pinOnDeleteReceiptKey, _pinOnApplyDiscountKey, _pinOnIssueRefundKey,
      _pinOnAddCategoryKey, _pinOnEditCategoryKey, _pinOnDeleteCategoryKey, _pinOnViewCategoriesKey,
      _pinOnViewCustomersKey, _pinOnAddCustomerKey, _pinOnEditCustomerKey, _pinOnDeleteCustomerKey,
      _pinOnViewEmployeesKey, _pinOnAddEmployeeKey, _pinOnEditEmployeeKey, _pinOnDeleteEmployeeKey,
      _pinOnViewStoresKey, _pinOnAddStoreKey, _pinOnEditStoreKey, _pinOnDeleteStoreKey,
      _pinOnReportsKey, _pinOnViewFinancialReportsKey, _pinOnViewInventoryReportsKey, _pinOnExportReportsKey,
      _pinOnHardwareSetupKey, _pinOnDataSyncKey, _pinOnClearAllDataKey,
      _pinOnManagePromotionsKey, _pinOnViewNotificationsKey,
      _pinOnTaxSettingsKey, _pinOnReceiptSettingsKey, _pinOnChangePinKey,
    ];
    
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
