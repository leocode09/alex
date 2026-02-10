import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/sale_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/product.dart';
import '../../../models/sale.dart';
import '../../../providers/printer_provider.dart';
import '../../../providers/receipt_provider.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';
import '../../../services/data_sync_triggers.dart';
import 'receipts_page.dart';

class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});

  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends ConsumerState<SalesPage>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _cart = [];
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _paymentMethod = 'Cash';
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _cashReceivedController = TextEditingController();
  late TabController _tabController;
  SharedPreferences? _prefs;
  bool _hasLoadedEditingReceipt = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initPrefs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we're editing a receipt and load it into the cart
    _loadEditingReceipt();
  }

  Future<void> _loadEditingReceipt() async {
    final editingReceipt = ref.watch(editingReceiptProvider);
    if (editingReceipt != null && !_hasLoadedEditingReceipt) {
      _hasLoadedEditingReceipt = true;
      // Load the receipt items into the cart
      setState(() {
        _cart.clear();
        for (var item in editingReceipt.items) {
          _cart.add({
            'id': item.productId,
            'name': item.productName,
            'price': item.price,
            'quantity': item.quantity,
          });
        }
        if (editingReceipt.customerId != null) {
          _customerController.text = editingReceipt.customerId!;
        }
        _paymentMethod = editingReceipt.paymentMethod;
      });
      _saveCart();
      // Switch to products tab so user can add items
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _tabController.index = 0;
        }
      });
    } else if (editingReceipt == null && _hasLoadedEditingReceipt) {
      // Reset the flag when editing is cancelled
      _hasLoadedEditingReceipt = false;
    }
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadCart();
  }

  void _loadCart() {
    if (_prefs == null) return;
    final cartString = _prefs!.getString('cart');
    if (cartString != null && mounted) {
      setState(() {
        _cart.clear();
        final List<dynamic> decodedCart = jsonDecode(cartString);
        _cart.addAll(decodedCart.cast<Map<String, dynamic>>());
      });
    }
  }

  Future<void> _saveCart() async {
    if (_prefs == null) return;
    final cartString = jsonEncode(_cart);
    await _prefs!.setString('cart', cartString);
  }

  double get _subtotal {
    return _cart.fold(0.0, (sum, item) {
      final itemPrice = item['price'];
      return sum + (itemPrice * item['quantity']);
    });
  }

  double get _total {
    return _subtotal;
  }

  List<Product> _getFilteredProducts(List<Product> allProducts) {
    final query = _searchController.text.toLowerCase();
    return allProducts.where((product) {
      final matchesCategory =
          _selectedCategory == 'All' || product.category == _selectedCategory;
      final matchesSearch =
          query.isEmpty || product.name.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  int _getCartQuantity(Product product) {
    final index = _cart.indexWhere((item) => item['id'] == product.id);
    if (index >= 0) {
      return _cart[index]['quantity'];
    }
    return 0;
  }

  void _removeProductFromCart(Product product) {
    setState(() {
      _cart.removeWhere((item) => item['id'] == product.id);
    });
    _saveCart();
    HapticFeedback.mediumImpact();
  }

  void _addToCart(Product product) {
    setState(() {
      final existingIndex =
          _cart.indexWhere((item) => item['id'] == product.id);
      if (existingIndex >= 0) {
        if (_cart[existingIndex]['quantity'] < product.stock) {
          _cart[existingIndex]['quantity']++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Not enough stock for ${product.name}')),
          );
        }
      } else {
        _cart.add({
          'id': product.id,
          'name': product.name,
          'price': product.price,
          'quantity': 1,
          'stock': product.stock,
        });
      }
    });
    _saveCart();
    HapticFeedback.lightImpact();
  }

  void _removeFromCart(int index) {
    setState(() {
      if (_cart[index]['quantity'] > 1) {
        _cart[index]['quantity']--;
      } else {
        _cart.removeAt(index);
      }
    });
    _saveCart();
    HapticFeedback.lightImpact();
  }

  Future<void> _showEditPriceDialog(BuildContext context, int index) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForApplyDiscount(),
      title: 'Adjust Price',
      subtitle: 'Enter PIN to adjust item price',
    );
    if (!allowed) {
      return;
    }
    if (!mounted) {
      return;
    }

    final item = _cart[index];
    final priceController = TextEditingController(
      text: item['price'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Price - ${item['name']}'),
        content: TextField(
          controller: priceController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Price',
            prefixText: '\$',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(priceController.text);
              if (newPrice != null && newPrice > 0) {
                setState(() {
                  _cart[index]['price'] = newPrice;
                });
                _saveCart();
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid price'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Map<String, int> _buildCartQuantities() {
    final quantities = <String, int>{};
    for (final item in _cart) {
      final productId = item['id'] as String?;
      final quantity = item['quantity'] as int?;
      if (productId == null || quantity == null) {
        continue;
      }
      quantities[productId] = (quantities[productId] ?? 0) + quantity;
    }
    return quantities;
  }

  Map<String, int> _buildSaleQuantities(List<SaleItem> items) {
    final quantities = <String, int>{};
    for (final item in items) {
      quantities[item.productId] =
          (quantities[item.productId] ?? 0) + item.quantity;
    }
    return quantities;
  }

  Map<String, int> _buildStockDeltas({
    required Map<String, int> oldQuantities,
    required Map<String, int> newQuantities,
  }) {
    final stockDeltas = <String, int>{};
    final productIds = <String>{...oldQuantities.keys, ...newQuantities.keys};
    for (final productId in productIds) {
      final oldQuantity = oldQuantities[productId] ?? 0;
      final newQuantity = newQuantities[productId] ?? 0;
      final delta = oldQuantity - newQuantity;
      if (delta != 0) {
        stockDeltas[productId] = delta;
      }
    }
    return stockDeltas;
  }

  Map<String, int> _invertStockDeltas(Map<String, int> deltas) {
    return {
      for (final entry in deltas.entries) entry.key: -entry.value,
    };
  }

  void _processPayment(String method) async {
    if (_cart.isEmpty) return;

    final totalAmount = _total;
    final editingReceipt = ref.read(editingReceiptProvider);
    final isEditingMode = editingReceipt != null;

    if (isEditingMode) {
      final allowed = await PinProtection.requirePinIfNeeded(
        context,
        isRequired: () => PinService().isPinRequiredForEditReceipt(),
        title: 'Edit Receipt',
        subtitle: 'Enter PIN to update receipt',
      );
      if (!allowed) {
        return;
      }
    } else {
      final allowed = await PinProtection.requirePinIfNeeded(
        context,
        isRequired: () => PinService().isPinRequiredForCreateSale(),
        title: 'Create Sale',
        subtitle: 'Enter PIN to create a sale',
      );
      if (!allowed) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    // Capture navigators before async gap
    // showDialog uses root navigator by default
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    // showModalBottomSheet uses local navigator (Shell) by default
    final localNavigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final productRepo = ref.read(productRepositoryProvider);
      final saleRepo = ref.read(saleRepositoryProvider);
      final authState = ref.read(authProvider);
      final saleItems = _cart.map((item) {
        return SaleItem(
          productId: item['id'],
          productName: item['name'],
          quantity: item['quantity'],
          price: item['price'],
        );
      }).toList();

      final oldQuantities = isEditingMode
          ? _buildSaleQuantities(editingReceipt!.items)
          : <String, int>{};
      final newQuantities = _buildCartQuantities();
      final stockDeltas = _buildStockDeltas(
        oldQuantities: oldQuantities,
        newQuantities: newQuantities,
      );
      bool stockApplied = false;
      bool printFailed = false;

      await productRepo.applyStockChanges(stockDeltas);
      stockApplied = stockDeltas.isNotEmpty;

      try {
        // Calculate cash received and change for Cash payments
        double? cashReceived;
        double? change;
        if (method == 'Cash') {
          final cashReceivedValue =
              double.tryParse(_cashReceivedController.text);
          if (cashReceivedValue != null && cashReceivedValue > 0) {
            cashReceived = cashReceivedValue;
            final difference = cashReceivedValue - totalAmount;
            if (difference >= 0) {
              change = difference;
            }
          }
        }

        if (isEditingMode) {
          final updatedSale = Sale(
            id: editingReceipt.id,
            items: saleItems,
            total: totalAmount,
            paymentMethod: method,
            employeeId: editingReceipt.employeeId,
            customerId: _customerController.text.isNotEmpty
                ? _customerController.text
                : null,
            cashReceived: cashReceived,
            change: change,
            createdAt: editingReceipt.createdAt,
          );

          final updated = await saleRepo.updateSale(updatedSale);
          if (!updated) {
            throw Exception('Failed to update receipt.');
          }
          await DataSyncTriggers.trigger(reason: 'receipt_updated');

          // Clear editing state
          ref.read(editingReceiptProvider.notifier).state = null;
        } else {
          // Get current user email or default
          String employeeId = 'default-employee';
          if (authState.hasValue && authState.value == true) {
            final prefs = await SharedPreferences.getInstance();
            employeeId = prefs.getString('userEmail') ?? 'default-employee';
          }

          final sale = Sale(
            id: const Uuid().v4(),
            items: saleItems,
            total: totalAmount,
            paymentMethod: method,
            employeeId: employeeId,
            customerId: _customerController.text.isNotEmpty
                ? _customerController.text
                : null,
            cashReceived: cashReceived,
            change: change,
            createdAt: DateTime.now(),
          );

          final inserted = await saleRepo.insertSale(sale);
          if (!inserted) {
            throw Exception('Failed to save sale.');
          }
          await DataSyncTriggers.trigger(reason: 'sale_created');

          // Attempt to print receipt
          try {
            final printerService = ref.read(printerServiceProvider);
            final receiptSettings = ref.read(receiptSettingsProvider);
            await printerService.printReceipt(sale, receiptSettings);
          } catch (e) {
            printFailed = true;
            debugPrint('Auto-print failed: $e');
          }
        }
      } catch (e) {
        if (stockApplied) {
          try {
            await productRepo.applyStockChanges(_invertStockDeltas(stockDeltas));
          } catch (rollbackError) {
            throw Exception('$e Stock rollback failed: $rollbackError');
          }
        }
        rethrow;
      }

      // 4. Update UI State
      ref.invalidate(productsProvider);
      ref.invalidate(lowStockProductsProvider);
      ref.invalidate(totalInventoryValueProvider);
      ref.invalidate(todaysSalesCountProvider);
      ref.invalidate(todaysRevenueProvider);
      ref.invalidate(salesProvider);
      ref.invalidate(totalRevenueProvider);
      ref.invalidate(totalSalesCountProvider);

      // 5. Clear Local State
      setState(() {
        _cart.clear();
        _customerController.clear();
        _cashReceivedController.clear();
        _paymentMethod = 'Cash';
      });
      _saveCart();

      // 6. Navigation & Feedback
      if (mounted) {
        rootNavigator.pop(); // Close loading (Dialog)
        localNavigator.pop(); // Close checkout sheet (BottomSheet)
        _tabController.animateTo(0); // Go to products tab

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEditingMode
                        ? 'Receipt updated successfully! \$${totalAmount.toStringAsFixed(2)}'
                        : 'Payment successful! \$${totalAmount.toStringAsFixed(2)}${printFailed ? "\n(Print failed: Check printer connection)" : ""}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        rootNavigator.pop(); // Close loading
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _checkout() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Checkout',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Subtotal', _subtotal),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '\$${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Payment Method',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildPaymentMethodChip(
                          setModalState, 'Cash', Icons.money)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildPaymentMethodChip(
                          setModalState, 'Card', Icons.credit_card)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildPaymentMethodChip(
                          setModalState, 'Mobile Money', Icons.phone_android)),
                ],
              ),
              if (_paymentMethod == 'Cash') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _cashReceivedController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cash Received',
                    prefixText: '\$',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  onChanged: (_) => setModalState(() {}),
                ),
                Builder(
                  builder: (context) {
                    final cashReceived = double.tryParse(_cashReceivedController.text) ?? 0.0;
                    if (cashReceived > 0) {
                      final difference = cashReceived - _total;
                      if (difference >= 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Change Due',
                                  style: TextStyle(
                                    color: Colors.green[900],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '\$${difference.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.green[900],
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Amount Due',
                                  style: TextStyle(
                                    color: Colors.orange[900],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '\$${(-difference).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.orange[900],
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _processPayment(_paymentMethod),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Pay \$${_total.toStringAsFixed(2)}'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChip(
      StateSetter setModalState, String method, IconData icon) {
    final isSelected = _paymentMethod == method;
    return InkWell(
      onTap: () => setModalState(() => _paymentMethod = method),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
          border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.grey[600], size: 20),
            const SizedBox(height: 4),
            Text(
              method,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildCartSummaryRow(String label, double value, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? Colors.black : Colors.grey[600],
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 16 : 12,
            color: value < 0
                ? Colors.green[700]
                : (isBold ? Colors.black : Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final editingReceipt = ref.watch(editingReceiptProvider);
    final isEditingMode = editingReceipt != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditingMode ? 'Edit Receipt' : 'Sales',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        leading: isEditingMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  // Cancel editing and clear cart
                  ref.read(editingReceiptProvider.notifier).state = null;
                  setState(() {
                    _cart.clear();
                    _customerController.clear();
                    _paymentMethod = 'Cash';
                  });
                  _saveCart();
                },
              )
            : null,
        backgroundColor: isEditingMode ? Colors.orange[700] : null,
        bottom: TabBar(
          controller: _tabController,
          onTap: _handleTabTap,
          labelColor: isEditingMode
              ? Colors.white
              : Theme.of(context).colorScheme.primary,
          unselectedLabelColor: isEditingMode ? Colors.white70 : Colors.grey,
          indicatorColor: isEditingMode
              ? Colors.white
              : Theme.of(context).colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            const Tab(text: 'Products'),
            Tab(text: 'Cart (${_cart.length})'),
            const Tab(text: 'Receipts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Products Tab
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: ['All', 'Beverages', 'Food', 'Snacks', 'Household']
                      .map((category) {
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected)
                            setState(() => _selectedCategory = category);
                        },
                        backgroundColor: Colors.white,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.grey[300]!),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: productsAsync.when(
                  data: (products) {
                    final filtered = _getFilteredProducts(products);
                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            const Text('No products found',
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final allowed = await PinProtection.requirePinIfNeeded(
                                  context,
                                  isRequired: () => PinService().isPinRequiredForAddProduct(),
                                  title: 'Add Product',
                                  subtitle: 'Enter PIN to add a product',
                                );
                                if (!allowed) {
                                  return;
                                }
                                if (!mounted) {
                                  return;
                                }
                                final searchQuery =
                                    _searchController.text.trim();
                                if (searchQuery.isNotEmpty) {
                                  context.push(
                                      '/products/add?name=${Uri.encodeComponent(searchQuery)}');
                                } else {
                                  context.push('/products/add');
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Create Product'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        final cartQuantity = _getCartQuantity(product);
                        final isInCart = cartQuantity > 0;

                        return InkWell(
                          onTap: () => _addToCart(product),
                          onLongPress: () => _removeProductFromCart(product),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isInCart
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[200]!,
                                width: isInCart ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isInCart
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.05)
                                              : Colors.grey[100],
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(8)),
                                        ),
                                        child: Stack(
                                          children: [
                                            Center(
                                              child: Icon(
                                                  Icons.inventory_2_outlined,
                                                  color: isInCart
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                      : Colors.grey[400],
                                                  size: 32),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '\$${product.price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11),
                                          ),
                                          Text(
                                            'Stock: ${product.stock}',
                                            style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (isInCart)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$cartQuantity',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),

          // Cart Tab
          Column(
            children: [
              Expanded(
                child: _cart.isEmpty
                    ? const Center(child: Text('Cart is empty'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cart.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _cart[index];

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item['name'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500)),
                                      InkWell(
                                        onTap: () => _showEditPriceDialog(
                                            context, index),
                                        child: Row(
                                          children: [
                                            Text(
                                              '\$${item['price'].toStringAsFixed(2)}',
                                              style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.edit,
                                                size: 14,
                                                color: Colors.blue[700]),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 28),
                                      onPressed: () => _removeFromCart(index),
                                    ),
                                    SizedBox(
                                      width: 32,
                                      child: Text(
                                        '${item['quantity']}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline,
                                          size: 28),
                                      onPressed: () => _addToCart(Product(
                                        id: item['id'],
                                        name: item['name'],
                                        price: item['price'],
                                        stock: item['stock'],
                                        category: '',
                                        sku: '',
                                      )),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      TextField(
                        controller: _customerController,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Customer (Optional)',
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline, size: 18),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            _buildCartSummaryRow('Subtotal', _subtotal, false),
                            const Divider(height: 12),
                            _buildCartSummaryRow('Total', _total, true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _checkout,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            backgroundColor:
                                isEditingMode ? Colors.orange[700] : null,
                          ),
                          child: Text(
                            isEditingMode ? 'Update Receipt' : 'Checkout',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Receipts Tab
          const ReceiptsTab(),
        ],
      ),
    );
  }

  Future<void> _handleTabTap(int index) async {
    final previousIndex = _tabController.index;
    if (index == previousIndex) {
      return;
    }

    if (index == 2) {
      final allowed = await PinProtection.requirePinIfNeeded(
        context,
        isRequired: () => PinService().isPinRequiredForViewSalesHistory(),
        title: 'Sales History',
        subtitle: 'Enter PIN to view receipts',
      );
      if (!allowed && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _tabController.index = previousIndex;
          }
        });
      }
    }
  }
}
