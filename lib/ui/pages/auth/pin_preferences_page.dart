import 'package:flutter/material.dart';
import '../../../services/pin_service.dart';

class PinPreferencesPage extends StatefulWidget {
  const PinPreferencesPage({super.key});

  @override
  State<PinPreferencesPage> createState() => _PinPreferencesPageState();
}

class _PinPreferencesPageState extends State<PinPreferencesPage> {
  final PinService _pinService = PinService();
  
  // Auth & General
  bool _requireOnLogin = true;
  bool _requireOnSettings = false;
  bool _requireOnDashboard = false;
  
  // Products
  bool _requireOnAddProduct = false;
  bool _requireOnEditProduct = false;
  bool _requireOnDeleteProduct = false;
  bool _requireOnViewProductDetails = false;
  bool _requireOnScanBarcode = false;
  bool _requireOnAdjustStock = false;
  
  // Sales
  bool _requireOnCreateSale = false;
  bool _requireOnViewSalesHistory = false;
  bool _requireOnEditReceipt = false;
  bool _requireOnDeleteReceipt = false;
  bool _requireOnApplyDiscount = false;
  bool _requireOnIssueRefund = false;
  
  // Categories
  bool _requireOnAddCategory = false;
  bool _requireOnEditCategory = false;
  bool _requireOnDeleteCategory = false;
  bool _requireOnViewCategories = false;
  
  // Customers
  bool _requireOnViewCustomers = false;
  bool _requireOnAddCustomer = false;
  bool _requireOnEditCustomer = false;
  bool _requireOnDeleteCustomer = false;
  
  // Employees
  bool _requireOnViewEmployees = false;
  bool _requireOnAddEmployee = false;
  bool _requireOnEditEmployee = false;
  bool _requireOnDeleteEmployee = false;
  
  // Stores
  bool _requireOnViewStores = false;
  bool _requireOnAddStore = false;
  bool _requireOnEditStore = false;
  bool _requireOnDeleteStore = false;
  
  // Reports & Analytics
  bool _requireOnReports = false;
  bool _requireOnViewFinancialReports = false;
  bool _requireOnViewInventoryReports = false;
  bool _requireOnExportReports = false;
  
  // System & Data Management
  bool _requireOnHardwareSetup = false;
  bool _requireOnDataSync = false;
  bool _requireOnClearAllData = true;
  bool _requireOnManagePromotions = false;
  bool _requireOnViewNotifications = false;
  
  // Settings Subsections
  bool _requireOnTaxSettings = false;
  bool _requireOnReceiptSettings = false;
  bool _requireOnChangePin = true;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await _pinService.getPinPreferences();
    setState(() {
      // Auth & General
      _requireOnLogin = prefs['login'] ?? true;
      _requireOnSettings = prefs['settings'] ?? false;
      _requireOnDashboard = prefs['dashboard'] ?? false;
      
      // Products
      _requireOnAddProduct = prefs['addProduct'] ?? false;
      _requireOnEditProduct = prefs['editProduct'] ?? false;
      _requireOnDeleteProduct = prefs['deleteProduct'] ?? false;
      _requireOnViewProductDetails = prefs['viewProductDetails'] ?? false;
      _requireOnScanBarcode = prefs['scanBarcode'] ?? false;
      _requireOnAdjustStock = prefs['adjustStock'] ?? false;
      
      // Sales
      _requireOnCreateSale = prefs['createSale'] ?? false;
      _requireOnViewSalesHistory = prefs['viewSalesHistory'] ?? false;
      _requireOnEditReceipt = prefs['editReceipt'] ?? false;
      _requireOnDeleteReceipt = prefs['deleteReceipt'] ?? false;
      _requireOnApplyDiscount = prefs['applyDiscount'] ?? false;
      _requireOnIssueRefund = prefs['issueRefund'] ?? false;
      
      // Categories
      _requireOnAddCategory = prefs['addCategory'] ?? false;
      _requireOnEditCategory = prefs['editCategory'] ?? false;
      _requireOnDeleteCategory = prefs['deleteCategory'] ?? false;
      _requireOnViewCategories = prefs['viewCategories'] ?? false;
      
      // Customers
      _requireOnViewCustomers = prefs['viewCustomers'] ?? false;
      _requireOnAddCustomer = prefs['addCustomer'] ?? false;
      _requireOnEditCustomer = prefs['editCustomer'] ?? false;
      _requireOnDeleteCustomer = prefs['deleteCustomer'] ?? false;
      
      // Employees
      _requireOnViewEmployees = prefs['viewEmployees'] ?? false;
      _requireOnAddEmployee = prefs['addEmployee'] ?? false;
      _requireOnEditEmployee = prefs['editEmployee'] ?? false;
      _requireOnDeleteEmployee = prefs['deleteEmployee'] ?? false;
      
      // Stores
      _requireOnViewStores = prefs['viewStores'] ?? false;
      _requireOnAddStore = prefs['addStore'] ?? false;
      _requireOnEditStore = prefs['editStore'] ?? false;
      _requireOnDeleteStore = prefs['deleteStore'] ?? false;
      
      // Reports
      _requireOnReports = prefs['reports'] ?? false;
      _requireOnViewFinancialReports = prefs['viewFinancialReports'] ?? false;
      _requireOnViewInventoryReports = prefs['viewInventoryReports'] ?? false;
      _requireOnExportReports = prefs['exportReports'] ?? false;
      
      // System
      _requireOnHardwareSetup = prefs['hardwareSetup'] ?? false;
      _requireOnDataSync = prefs['dataSync'] ?? false;
      _requireOnClearAllData = prefs['clearAllData'] ?? true;
      _requireOnManagePromotions = prefs['managePromotions'] ?? false;
      _requireOnViewNotifications = prefs['viewNotifications'] ?? false;
      
      // Settings Subsections
      _requireOnTaxSettings = prefs['taxSettings'] ?? false;
      _requireOnReceiptSettings = prefs['receiptSettings'] ?? false;
      _requireOnChangePin = prefs['changePin'] ?? true;
      
      _isLoading = false;
    });
  }

  Future<void> _savePreferences() async {
    await _pinService.updatePinPreferences({
      // Auth & General
      'login': _requireOnLogin,
      'settings': _requireOnSettings,
      'dashboard': _requireOnDashboard,
      
      // Products
      'addProduct': _requireOnAddProduct,
      'editProduct': _requireOnEditProduct,
      'deleteProduct': _requireOnDeleteProduct,
      'viewProductDetails': _requireOnViewProductDetails,
      'scanBarcode': _requireOnScanBarcode,
      'adjustStock': _requireOnAdjustStock,
      
      // Sales
      'createSale': _requireOnCreateSale,
      'viewSalesHistory': _requireOnViewSalesHistory,
      'editReceipt': _requireOnEditReceipt,
      'deleteReceipt': _requireOnDeleteReceipt,
      'applyDiscount': _requireOnApplyDiscount,
      'issueRefund': _requireOnIssueRefund,
      
      // Categories
      'addCategory': _requireOnAddCategory,
      'editCategory': _requireOnEditCategory,
      'deleteCategory': _requireOnDeleteCategory,
      'viewCategories': _requireOnViewCategories,
      
      // Customers
      'viewCustomers': _requireOnViewCustomers,
      'addCustomer': _requireOnAddCustomer,
      'editCustomer': _requireOnEditCustomer,
      'deleteCustomer': _requireOnDeleteCustomer,
      
      // Employees
      'viewEmployees': _requireOnViewEmployees,
      'addEmployee': _requireOnAddEmployee,
      'editEmployee': _requireOnEditEmployee,
      'deleteEmployee': _requireOnDeleteEmployee,
      
      // Stores
      'viewStores': _requireOnViewStores,
      'addStore': _requireOnAddStore,
      'editStore': _requireOnEditStore,
      'deleteStore': _requireOnDeleteStore,
      
      // Reports
      'reports': _requireOnReports,
      'viewFinancialReports': _requireOnViewFinancialReports,
      'viewInventoryReports': _requireOnViewInventoryReports,
      'exportReports': _requireOnExportReports,
      
      // System
      'hardwareSetup': _requireOnHardwareSetup,
      'dataSync': _requireOnDataSync,
      'clearAllData': _requireOnClearAllData,
      'managePromotions': _requireOnManagePromotions,
      'viewNotifications': _requireOnViewNotifications,
      
      // Settings Subsections
      'taxSettings': _requireOnTaxSettings,
      'receiptSettings': _requireOnReceiptSettings,
      'changePin': _requireOnChangePin,
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN preferences updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('PIN Preferences', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.security,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Choose where to require PIN',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select which actions should require PIN verification for security',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Auth & General Section
                          _buildSectionHeader('Authentication & General'),
                          _buildPreferenceSwitch(
                            icon: Icons.login,
                            title: 'Login',
                            subtitle: 'Require PIN every time you log in',
                            value: _requireOnLogin,
                            onChanged: (value) => setState(() => _requireOnLogin = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.dashboard_outlined,
                            title: 'Dashboard Access',
                            subtitle: 'Require PIN to view dashboard',
                            value: _requireOnDashboard,
                            onChanged: (value) => setState(() => _requireOnDashboard = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.settings_outlined,
                            title: 'Settings Access',
                            subtitle: 'Require PIN to access settings',
                            value: _requireOnSettings,
                            onChanged: (value) => setState(() => _requireOnSettings = value),
                          ),
                          
                          // Products Section
                          const SizedBox(height: 24),
                          _buildSectionHeader('Products'),
                          _buildPreferenceSwitch(
                            icon: Icons.add_box_outlined,
                            title: 'Add Products',
                            subtitle: 'Require PIN when adding new products',
                            value: _requireOnAddProduct,
                            onChanged: (value) => setState(() => _requireOnAddProduct = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.edit_outlined,
                            title: 'Edit Products',
                            subtitle: 'Require PIN when editing existing products',
                            value: _requireOnEditProduct,
                            onChanged: (value) => setState(() => _requireOnEditProduct = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.delete_outlined,
                            title: 'Delete Products',
                            subtitle: 'Require PIN when deleting products',
                            value: _requireOnDeleteProduct,
                            onChanged: (value) => setState(() => _requireOnDeleteProduct = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.visibility_outlined,
                            title: 'View Product Details',
                            subtitle: 'Require PIN to view product details',
                            value: _requireOnViewProductDetails,
                            onChanged: (value) => setState(() => _requireOnViewProductDetails = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.qr_code_scanner,
                            title: 'Scan Barcode',
                            subtitle: 'Require PIN to scan product barcodes',
                            value: _requireOnScanBarcode,
                            onChanged: (value) => setState(() => _requireOnScanBarcode = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.inventory_2_outlined,
                            title: 'Adjust Stock/Inventory',
                            subtitle: 'Require PIN to adjust product stock levels',
                            value: _requireOnAdjustStock,
                            onChanged: (value) => setState(() => _requireOnAdjustStock = value),
                          ),
                          
                          // Sales Section
                          const SizedBox(height: 24),
                          _buildSectionHeader('Sales & Transactions'),
                          _buildPreferenceSwitch(
                            icon: Icons.point_of_sale,
                            title: 'Process Sale',
                            subtitle: 'Require PIN to create/complete sales',
                            value: _requireOnCreateSale,
                            onChanged: (value) => setState(() => _requireOnCreateSale = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.receipt_long_outlined,
                            title: 'View Sales History',
                            subtitle: 'Require PIN to view receipts and sales history',
                            value: _requireOnViewSalesHistory,
                            onChanged: (value) => setState(() => _requireOnViewSalesHistory = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.edit_note_outlined,
                            title: 'Edit Receipt',
                            subtitle: 'Require PIN to edit existing receipts',
                            value: _requireOnEditReceipt,
                            onChanged: (value) => setState(() => _requireOnEditReceipt = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.delete_sweep_outlined,
                            title: 'Delete Receipt',
                            subtitle: 'Require PIN to delete receipts/sales',
                            value: _requireOnDeleteReceipt,
                            onChanged: (value) => setState(() => _requireOnDeleteReceipt = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.percent_outlined,
                            title: 'Apply Discount',
                            subtitle: 'Require PIN to apply discounts',
                            value: _requireOnApplyDiscount,
                            onChanged: (value) => setState(() => _requireOnApplyDiscount = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.currency_exchange_outlined,
                            title: 'Issue Refund',
                            subtitle: 'Require PIN to process refunds',
                            value: _requireOnIssueRefund,
                            onChanged: (value) => setState(() => _requireOnIssueRefund = value),
                          ),
                          
                          // Categories Section
                          const SizedBox(height: 24),
                          _buildSectionHeader('Categories'),
                          _buildPreferenceSwitch(
                            icon: Icons.folder_outlined,
                            title: 'View Categories',
                            subtitle: 'Require PIN to access category management',
                            value: _requireOnViewCategories,
                            onChanged: (value) => setState(() => _requireOnViewCategories = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.create_new_folder_outlined,
                            title: 'Add Category',
                            subtitle: 'Require PIN to create new categories',
                            value: _requireOnAddCategory,
                            onChanged: (value) => setState(() => _requireOnAddCategory = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.drive_file_rename_outline,
                            title: 'Edit Category',
                            subtitle: 'Require PIN to edit categories',
                            value: _requireOnEditCategory,
                            onChanged: (value) => setState(() => _requireOnEditCategory = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.folder_delete_outlined,
                            title: 'Delete Category',
                            subtitle: 'Require PIN to delete categories',
                            value: _requireOnDeleteCategory,
                            onChanged: (value) => setState(() => _requireOnDeleteCategory = value),
                          ),
                          
                          // Customers Section
                          const SizedBox(height: 24),
                          _buildSectionHeader('Customers'),
                          _buildPreferenceSwitch(
                            icon: Icons.people_outline,
                            title: 'View Customers',
                            subtitle: 'Require PIN to access customer list',
                            value: _requireOnViewCustomers,
                            onChanged: (value) => setState(() => _requireOnViewCustomers = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.person_add_outlined,
                            title: 'Add Customer',
                            subtitle: 'Require PIN to add new customers',
                            value: _requireOnAddCustomer,
                            onChanged: (value) => setState(() => _requireOnAddCustomer = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.edit_outlined,
                            title: 'Edit Customer',
                            subtitle: 'Require PIN to edit customer information',
                            value: _requireOnEditCustomer,
                            onChanged: (value) => setState(() => _requireOnEditCustomer = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.person_remove_outlined,
                            title: 'Delete Customer',
                            subtitle: 'Require PIN to delete customers',
                            value: _requireOnDeleteCustomer,
                            onChanged: (value) => setState(() => _requireOnDeleteCustomer = value),
                          ),
                          
                          // Employees Section
                          const SizedBox(height: 24),
                          _buildSectionHeader('Employees'),
                          _buildPreferenceSwitch(
                            icon: Icons.badge_outlined,
                            title: 'View Employees',
                            subtitle: 'Require PIN to access employee list',
                            value: _requireOnViewEmployees,
                            onChanged: (value) => setState(() => _requireOnViewEmployees = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.person_add_alt_outlined,
                            title: 'Add Employee',
                            subtitle: 'Require PIN to add new employees',
                            value: _requireOnAddEmployee,
                            onChanged: (value) => setState(() => _requireOnAddEmployee = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.manage_accounts_outlined,
                            title: 'Edit Employee',
                            subtitle: 'Require PIN to edit employee information',
                            value: _requireOnEditEmployee,
                            onChanged: (value) => setState(() => _requireOnEditEmployee = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.person_off_outlined,
                            title: 'Delete Employee',
                            subtitle: 'Require PIN to delete employees',
                            value: _requireOnDeleteEmployee,
                            onChanged: (value) => setState(() => _requireOnDeleteEmployee = value),
                          ),
                          
                          // Stores Section
                          const SizedBox(height: 24),
                          _buildSectionHeader('Stores'),
                          _buildPreferenceSwitch(
                            icon: Icons.store_outlined,
                            title: 'View Stores',
                            subtitle: 'Require PIN to access store management',
                            value: _requireOnViewStores,
                            onChanged: (value) => setState(() => _requireOnViewStores = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.add_business_outlined,
                            title: 'Add Store',
                            subtitle: 'Require PIN to add new stores',
                            value: _requireOnAddStore,
                            onChanged: (value) => setState(() => _requireOnAddStore = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.edit_location_outlined,
                            title: 'Edit Store',
                            subtitle: 'Require PIN to edit store information',
                            value: _requireOnEditStore,
                            onChanged: (value) => setState(() => _requireOnEditStore = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.store_mall_directory_outlined,
                            title: 'Delete Store',
                            subtitle: 'Require PIN to delete stores',
                            value: _requireOnDeleteStore,
                            onChanged: (value) => setState(() => _requireOnDeleteStore = value),
                          ),
                          
                          // Reports Section
                          const SizedBox(height: 24),
                          _buildSectionHeader('Reports & Analytics'),
                          _buildPreferenceSwitch(
                            icon: Icons.bar_chart_outlined,
                            title: 'Access Reports',
                            subtitle: 'Require PIN to view reports page',
                            value: _requireOnReports,
                            onChanged: (value) => setState(() => _requireOnReports = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.account_balance_outlined,
                            title: 'Financial Reports',
                            subtitle: 'Require PIN to view financial reports',
                            value: _requireOnViewFinancialReports,
                            onChanged: (value) => setState(() => _requireOnViewFinancialReports = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.inventory_outlined,
                            title: 'Inventory Reports',
                            subtitle: 'Require PIN to view inventory reports',
                            value: _requireOnViewInventoryReports,
                            onChanged: (value) => setState(() => _requireOnViewInventoryReports = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.file_download_outlined,
                            title: 'Export Reports',
                            subtitle: 'Require PIN to export report data',
                            value: _requireOnExportReports,
                            onChanged: (value) => setState(() => _requireOnExportReports = value),
                          ),
                          
                          // System & Data Management Section
                          const SizedBox(height: 24),
                          _buildSectionHeader('System & Data Management'),
                          _buildPreferenceSwitch(
                            icon: Icons.devices_outlined,
                            title: 'Hardware Setup',
                            subtitle: 'Require PIN to configure hardware',
                            value: _requireOnHardwareSetup,
                            onChanged: (value) => setState(() => _requireOnHardwareSetup = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.sync_outlined,
                            title: 'Data Sync',
                            subtitle: 'Require PIN to sync data between devices',
                            value: _requireOnDataSync,
                            onChanged: (value) => setState(() => _requireOnDataSync = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.delete_forever_outlined,
                            title: 'Clear All Data',
                            subtitle: 'Require PIN to clear all application data',
                            value: _requireOnClearAllData,
                            onChanged: (value) => setState(() => _requireOnClearAllData = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.local_offer_outlined,
                            title: 'Manage Promotions',
                            subtitle: 'Require PIN to create/edit promotions',
                            value: _requireOnManagePromotions,
                            onChanged: (value) => setState(() => _requireOnManagePromotions = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.notifications_outlined,
                            title: 'View Notifications',
                            subtitle: 'Require PIN to access notifications',
                            value: _requireOnViewNotifications,
                            onChanged: (value) => setState(() => _requireOnViewNotifications = value),
                          ),
                          
                          // Settings Subsections
                          const SizedBox(height: 24),
                          _buildSectionHeader('Settings Configuration'),
                          _buildPreferenceSwitch(
                            icon: Icons.calculate_outlined,
                            title: 'Tax Settings',
                            subtitle: 'Require PIN to configure tax settings',
                            value: _requireOnTaxSettings,
                            onChanged: (value) => setState(() => _requireOnTaxSettings = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.receipt_outlined,
                            title: 'Receipt Settings',
                            subtitle: 'Require PIN to configure receipt settings',
                            value: _requireOnReceiptSettings,
                            onChanged: (value) => setState(() => _requireOnReceiptSettings = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.lock_reset_outlined,
                            title: 'Change PIN',
                            subtitle: 'Require current PIN to change PIN',
                            value: _requireOnChangePin,
                            onChanged: (value) => setState(() => _requireOnChangePin = value),
                          ),
                          
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _savePreferences,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Preferences',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildPreferenceSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SwitchListTile(
          secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
