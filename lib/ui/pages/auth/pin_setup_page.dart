import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/pin_service.dart';

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  final PinService _pinService = PinService();
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _showPreferences = false;
  List<String> _shuffledNumbers = [];
  
  // PIN requirement preferences - Auth & General
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

  @override
  void initState() {
    super.initState();
    _shuffleNumbers();
  }

  void _shuffleNumbers() {
    _shuffledNumbers = List.generate(10, (index) => index.toString());
    _shuffledNumbers.shuffle(Random());
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (!_isConfirming) {
        if (_pin.length < 4) {
          _pin += number;
          if (_pin.length == 4) {
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() {
                _isConfirming = true;
                _shuffleNumbers();
              });
            });
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += number;
          if (_confirmPin.length == 4) {
            _verifyPins();
          }
        }
      }
    });
  }

  void _onDeletePressed() {
    setState(() {
      if (!_isConfirming) {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      }
    });
  }

  Future<void> _verifyPins() async {
    if (_pin == _confirmPin) {
      setState(() {
        _showPreferences = true;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PINs do not match. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _pin = '';
          _confirmPin = '';
          _isConfirming = false;
          _shuffleNumbers();
        });
      }
    }
  }

  Future<void> _savePinWithPreferences() async {
    await _pinService.setPin(
      _pin,
      // Auth & General
      requireOnLogin: _requireOnLogin,
      requireOnSettings: _requireOnSettings,
      requireOnDashboard: _requireOnDashboard,
      
      // Products
      requireOnAddProduct: _requireOnAddProduct,
      requireOnEditProduct: _requireOnEditProduct,
      requireOnDeleteProduct: _requireOnDeleteProduct,
      requireOnViewProductDetails: _requireOnViewProductDetails,
      requireOnScanBarcode: _requireOnScanBarcode,
      requireOnAdjustStock: _requireOnAdjustStock,
      
      // Sales
      requireOnCreateSale: _requireOnCreateSale,
      requireOnViewSalesHistory: _requireOnViewSalesHistory,
      requireOnEditReceipt: _requireOnEditReceipt,
      requireOnDeleteReceipt: _requireOnDeleteReceipt,
      requireOnApplyDiscount: _requireOnApplyDiscount,
      requireOnIssueRefund: _requireOnIssueRefund,
      
      // Categories
      requireOnAddCategory: _requireOnAddCategory,
      requireOnEditCategory: _requireOnEditCategory,
      requireOnDeleteCategory: _requireOnDeleteCategory,
      requireOnViewCategories: _requireOnViewCategories,
      
      // Customers
      requireOnViewCustomers: _requireOnViewCustomers,
      requireOnAddCustomer: _requireOnAddCustomer,
      requireOnEditCustomer: _requireOnEditCustomer,
      requireOnDeleteCustomer: _requireOnDeleteCustomer,
      
      // Employees
      requireOnViewEmployees: _requireOnViewEmployees,
      requireOnAddEmployee: _requireOnAddEmployee,
      requireOnEditEmployee: _requireOnEditEmployee,
      requireOnDeleteEmployee: _requireOnDeleteEmployee,
      
      // Stores
      requireOnViewStores: _requireOnViewStores,
      requireOnAddStore: _requireOnAddStore,
      requireOnEditStore: _requireOnEditStore,
      requireOnDeleteStore: _requireOnDeleteStore,
      
      // Reports & Analytics
      requireOnReports: _requireOnReports,
      requireOnViewFinancialReports: _requireOnViewFinancialReports,
      requireOnViewInventoryReports: _requireOnViewInventoryReports,
      requireOnExportReports: _requireOnExportReports,
      
      // System & Data Management
      requireOnHardwareSetup: _requireOnHardwareSetup,
      requireOnDataSync: _requireOnDataSync,
      requireOnClearAllData: _requireOnClearAllData,
      requireOnManagePromotions: _requireOnManagePromotions,
      requireOnViewNotifications: _requireOnViewNotifications,
      
      // Settings Subsections
      requireOnTaxSettings: _requireOnTaxSettings,
      requireOnReceiptSettings: _requireOnReceiptSettings,
      requireOnChangePin: _requireOnChangePin,
    );
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showPreferences) {
      return _buildPreferencesScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                _isConfirming ? 'Confirm PIN' : 'Create PIN',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Enter your PIN again to confirm'
                    : 'Create a 4-digit PIN to secure your app',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isConfirming
                                ? index < _confirmPin.length
                                : index < _pin.length)
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _buildKeypad(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('PIN Settings', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
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
                  onPressed: _savePinWithPreferences,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Complete Setup',
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

  Widget _buildKeypad() {
    return Column(
      children: [
        for (int i = 0; i < 3; i++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int j = 0; j < 3; j++)
                _buildKeypadButton(_shuffledNumbers[i * 3 + j]),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80, height: 80), // Empty space
            _buildKeypadButton(_shuffledNumbers[9]),
            _buildKeypadButton('⌫', isDelete: true),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String value, {bool isDelete = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () {
          if (isDelete) {
            _onDeletePressed();
          } else {
            _onNumberPressed(value);
          }
        },
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[100],
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isDelete ? 28 : 24,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
