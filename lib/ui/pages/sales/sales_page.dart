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
import '../../../providers/tax_provider.dart';
import '../../../models/product.dart';
import '../../../models/sale.dart';
import '../../../services/printer_service.dart';
import '../../../providers/printer_provider.dart';
import '../../../providers/receipt_provider.dart';
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
  final TextEditingController _discountController = TextEditingController();
  String _discountType = 'Fixed'; // 'Fixed' or 'Percentage'
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
      // Switch to cart tab to show the loaded items
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _tabController.animateTo(1);
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
    return _cart.fold(
        0.0, (sum, item) => sum + ((item['finalPrice'] ?? item['price']) * item['quantity']));
  }

  double get _discount {
    final discountValue = double.tryParse(_discountController.text) ?? 0.0;
    if (_discountType == 'Percentage') {
      return _subtotal * (discountValue / 100);
    }
    return discountValue;
  }

  double get _tax {
    final taxSettings = ref.read(taxSettingsProvider);
    if (!taxSettings.includeTax) return 0.0;
    return (_subtotal - _discount) * taxSettings.taxRate;
  }

  double get _total {
    return _subtotal - _discount + _tax;
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
          'finalPrice': product.finalPrice,
          'discount': product.totalDiscount,
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

  void _processPayment(String method) async {
    if (_cart.isEmpty) return;

    final totalAmount = _total;
    final editingReceipt = ref.read(editingReceiptProvider);
    final isEditingMode = editingReceipt != null;
    
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

      if (isEditingMode) {
        // EDITING MODE: Calculate stock differences and update
        final oldItems = editingReceipt.items;
        final Map<String, int> oldQuantities = {};
        for (var item in oldItems) {
          oldQuantities[item.productId] = (oldQuantities[item.productId] ?? 0) + item.quantity;
        }

        // 1. Validate and adjust stock for each item
        for (var cartItem in _cart) {
          final product = await productRepo.getProductById(cartItem['id']);
          if (product == null) {
            throw Exception('Product ${cartItem['name']} not found');
          }
          
          final oldQuantity = oldQuantities[cartItem['id']] ?? 0;
          final quantityDiff = cartItem['quantity'] - oldQuantity;
          
          if (quantityDiff > 0) {
            // Need more stock
            if (product.stock < quantityDiff) {
              throw Exception('Insufficient stock for ${cartItem['name']}');
            }
            await productRepo.decreaseStock(cartItem['id'], quantityDiff);
          } else if (quantityDiff < 0) {
            // Return stock
            await productRepo.increaseStock(cartItem['id'], -quantityDiff);
          }
        }

        // Check for removed items and restore their stock
        for (var oldItem in oldItems) {
          final stillInCart = _cart.any((cartItem) => cartItem['id'] == oldItem.productId);
          if (!stillInCart) {
            await productRepo.increaseStock(oldItem.productId, oldItem.quantity);
          }
        }

        // 3. Update Sale Record
        final saleItems = _cart.map((item) {
          return SaleItem(
            productId: item['id'],
            productName: item['name'],
            quantity: item['quantity'],
            price: item['price'],
            discount: item['discount'],
          );
        }).toList();

        final updatedSale = Sale(
          id: editingReceipt.id,
          items: saleItems,
          total: totalAmount,
          paymentMethod: method,
          employeeId: editingReceipt.employeeId,
          customerId: _customerController.text.isNotEmpty
              ? _customerController.text
              : null,
          createdAt: editingReceipt.createdAt,
        );

        await saleRepo.updateSale(updatedSale);

        // Clear editing state
        ref.read(editingReceiptProvider.notifier).state = null;

      } else {
        // NEW SALE MODE: Original logic
        // 1. Validate stock first
        for (var cartItem in _cart) {
          final product = await productRepo.getProductById(cartItem['id']);
          if (product == null) {
            throw Exception('Product ${cartItem['name']} not found');
          }
          if (product.stock < cartItem['quantity']) {
            throw Exception('Insufficient stock for ${cartItem['name']}');
          }
        }

        // 2. Process stock deduction
        for (var cartItem in _cart) {
          final success = await productRepo.decreaseStock(
            cartItem['id'],
            cartItem['quantity'],
          );
          if (!success) {
            throw Exception('Failed to update stock for ${cartItem['name']}');
          }
        }

        // 3. Create Sale Record
        final saleItems = _cart.map((item) {
          return SaleItem(
            productId: item['id'],
            productName: item['name'],
            quantity: item['quantity'],
            price: item['price'],
            discount: item['discount'],
          );
        }).toList();

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
          createdAt: DateTime.now(),
        );

        await saleRepo.insertSale(sale);

        // Attempt to print receipt
        String? printError;
        try {
          final printerService = ref.read(printerServiceProvider);
          final receiptSettings = ref.read(receiptSettingsProvider);
          await printerService.printReceipt(sale, receiptSettings);
        } catch (e) {
          printError = e.toString();
          debugPrint('Auto-print failed: $e');
        }
      }

      // 4. Update UI State
      ref.invalidate(productsProvider);
      ref.invalidate(todaysSalesCountProvider);
      ref.invalidate(todaysRevenueProvider);
      ref.invalidate(salesProvider);
      ref.invalidate(totalRevenueProvider);
      ref.invalidate(totalSalesCountProvider);

      // 5. Clear Local State
      setState(() {
        _cart.clear();
        _customerController.clear();
        _discountController.clear();
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
                        ? 'Receipt updated successfully! \$${totalAmount.toStringAsFixed(0)}'
                        : 'Payment successful! \$${totalAmount.toStringAsFixed(0)}${!isEditingMode && mounted ? "\n(Print failed: Check printer connection)" : ""}',
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
                    const SizedBox(height: 8),
                    if (_discount > 0) ...[
                      _buildSummaryRow(
                        'Cart Discount${_discountType == 'Percentage' ? ' (${_discountController.text}%)' : ''}',
                        -_discount,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Builder(builder: (context) {
                      final taxSettings = ref.watch(taxSettingsProvider);
                      final taxPercent =
                          (taxSettings.taxRate * 100).toStringAsFixed(0);
                      return _buildSummaryRow('Tax ($taxPercent%)', _tax);
                    }),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '\$${_total.toStringAsFixed(0)}',
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
                child: Text('Pay \$${_total.toStringAsFixed(0)}'),
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
          '\$${value.toStringAsFixed(0)}',
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
            color: value < 0 ? Colors.green[700] : (isBold ? Colors.black : Colors.grey[800]),
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
                    _discountController.clear();
                    _paymentMethod = 'Cash';
                  });
                  _saveCart();
                },
              )
            : null,
        backgroundColor: isEditingMode ? Colors.orange[700] : null,
        bottom: TabBar(
          controller: _tabController,
          labelColor: isEditingMode ? Colors.white : Theme.of(context).colorScheme.primary,
          unselectedLabelColor: isEditingMode ? Colors.white70 : Colors.grey,
          indicatorColor: isEditingMode ? Colors.white : Theme.of(context).colorScheme.primary,
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
                            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            const Text('No products found', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                final searchQuery = _searchController.text.trim();
                                if (searchQuery.isNotEmpty) {
                                  context.push('/products/add?name=${Uri.encodeComponent(searchQuery)}');
                                } else {
                                  context.push('/products/add');
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Create Product'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                                            if (product.hasDiscount)
                                              Positioned(
                                                top: 4,
                                                left: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'SALE',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
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
                                          if (product.hasDiscount) ...[
                                            Row(
                                              children: [
                                                Text(
                                                  '\$${product.price.toInt()}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[500],
                                                    decoration: TextDecoration.lineThrough,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '\$${product.finalPrice.toInt()}',
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Colors.green),
                                                ),
                                              ],
                                            ),
                                          ] else
                                            Text(
                                              '\$${product.price.toInt()}',
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
                          final hasDiscount = (item['discount'] ?? 0) > 0;
                          final finalPrice = item['finalPrice'] ?? item['price'];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
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
                                      if (hasDiscount) ...[
                                        Row(
                                          children: [
                                            Text(
                                              '\$${item['price'].toInt()}',
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 12,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '\$${finalPrice.toInt()}',
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                '-\$${item['discount'].toInt()}',
                                                style: TextStyle(
                                                  color: Colors.red[700],
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else
                                        Text(
                                          '\$${item['price'].toInt()}',
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12),
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
                        decoration: const InputDecoration(
                          labelText: 'Customer (Optional)',
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _discountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: _discountType == 'Percentage' ? 'Discount %' : 'Discount Amount',
                                isDense: true,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.local_offer),
                                suffixText: _discountType == 'Percentage' ? '%' : '\$',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _discountType,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Fixed', child: Text('Fixed', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Percentage', child: Text('%', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _discountType = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_discount > 0) ..[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.savings, size: 16, color: Colors.green[700]),
                              const SizedBox(width: 8),
                              Text(
                                'You save \$${_discount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            _buildCartSummaryRow('Subtotal', _subtotal, false),
                            if (_discount > 0) ..[
                              const SizedBox(height: 6),
                              _buildCartSummaryRow('Cart Discount', -_discount, false),
                            ],
                            const SizedBox(height: 6),
                            Builder(builder: (context) {
                              final taxSettings = ref.watch(taxSettingsProvider);
                              final taxPercent = (taxSettings.taxRate * 100).toStringAsFixed(0);
                              return _buildCartSummaryRow('Tax ($taxPercent%)', _tax, false);
                            }),
                            const Divider(height: 16),
                            _buildCartSummaryRow('Total', _total, true),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _checkout,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            backgroundColor: isEditingMode ? Colors.orange[700] : null,
                          ),
                          child: Text(isEditingMode ? 'Update Receipt' : 'Checkout'),
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
}
