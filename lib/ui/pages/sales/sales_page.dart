import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../themes/app_theme.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/sale_provider.dart';
import '../../../models/product.dart';
import '../../../models/sale.dart';

class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});

  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends ConsumerState<SalesPage> with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _cart = [];
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _paymentMethod = 'Cash';
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  late TabController _tabController;
  
  int _transactionsToday = 0;
  double _salesTarget = 500000;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTodaysTransactions();
  }

  void _loadTodaysTransactions() async {
    final count = await ref.read(todaysSalesCountProvider.future);
    if (mounted) {
      setState(() {
        _transactionsToday = count;
      });
    }
  }

  double get _subtotal {
    return _cart.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));
  }

  double get _discount {
    final discountValue = double.tryParse(_discountController.text) ?? 0.0;
    return discountValue;
  }

  double get _tax {
    return (_subtotal - _discount) * 0.18; // 18% tax
  }

  double get _total {
    return _subtotal - _discount + _tax;
  }

  List<Product> _getFilteredProducts(List<Product> allProducts) {
    final query = _searchController.text.toLowerCase();
    return allProducts.where((product) {
      final matchesCategory = _selectedCategory == 'All' || product.category == _selectedCategory;
      final matchesSearch = query.isEmpty || product.name.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cart.indexWhere((item) => item['id'] == product.id);
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
    HapticFeedback.lightImpact();
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _customerController.clear();
      _discountController.clear();
    });
  }

  void _processPayment(String method) async {
    if (_cart.isEmpty) return;

    // Capture values before clearing cart
    final totalAmount = _total;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get repositories
      final productRepo = ref.read(productRepositoryProvider);
      final saleRepo = ref.read(saleRepositoryProvider);

      // Update product stocks
      for (var cartItem in _cart) {
        await productRepo.decreaseStock(
          cartItem['id'],
          cartItem['quantity'],
        );
      }

      // Create sale items
      final saleItems = _cart.map((item) {
        return SaleItem(
          productId: item['id'],
          productName: item['name'],
          quantity: item['quantity'],
          price: item['price'],
        );
      }).toList();

      // Create sale
      final sale = Sale(
        id: const Uuid().v4(),
        items: saleItems,
        total: totalAmount,
        paymentMethod: method,
        employeeId: 'default-employee', // TODO: Add employee management
        customerId: _customerController.text.isNotEmpty 
            ? _customerController.text 
            : null,
      );

      // Save sale
      await saleRepo.insertSale(sale);

      // Refresh products provider to update stock display
      ref.invalidate(productsProvider);
      ref.invalidate(todaysSalesCountProvider);
      ref.invalidate(todaysRevenueProvider);

      setState(() {
        _cart.clear();
        _customerController.clear();
        _discountController.clear();
        _paymentMethod = 'Cash';
      });
      
      // Reload today's transactions
      _loadTodaysTransactions();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
      }
      
      // Wait a frame before closing checkout sheet
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Close checkout sheet
      if (mounted) {
        Navigator.of(context).pop(); // Close checkout sheet
      }
      
      // Wait before navigating
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Navigate to products page
      if (mounted) {
        _tabController.animateTo(0); // Go to products tab
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment successful! ${totalAmount.toStringAsFixed(0)} RWF ($method)'),
            backgroundColor: AppTheme.greenPantone,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog on error
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(BuildContext context, String method, double totalAmount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.greenLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppTheme.greenPantone,
                size: 64,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Successful!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paid via $method',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${totalAmount.toStringAsFixed(0)} RWF',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.greenPantone,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.print),
                    label: const Text('Print Receipt'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  Text(
                    'Payment Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Payment summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.amberLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Subtotal', _subtotal),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Discount', -_discount),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Tax (18%)', _tax),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          '${_total.toStringAsFixed(0)} RWF',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.greenPantone,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Payment method selection
              Text(
                'Payment Method',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentMethodCard(
                      context,
                      icon: Icons.money,
                      label: 'Cash',
                      isSelected: _paymentMethod == 'Cash',
                      onTap: () => setModalState(() => _paymentMethod = 'Cash'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentMethodCard(
                      context,
                      icon: Icons.credit_card,
                      label: 'Card',
                      isSelected: _paymentMethod == 'Card',
                      onTap: () => setModalState(() => _paymentMethod = 'Card'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentMethodCard(
                      context,
                      icon: Icons.phone_android,
                      label: 'Mobile',
                      isSelected: _paymentMethod == 'Mobile Money',
                      onTap: () => setModalState(() => _paymentMethod = 'Mobile Money'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Complete payment button
              ElevatedButton(
                onPressed: () => _processPayment(_paymentMethod),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.greenPantone,
                ),
                child: Text(
                  'Complete Payment - ${_total.toStringAsFixed(0)} RWF',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales / Register'),
            Text(
              '$_transactionsToday transactions today',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${_cart.length}'),
              isLabelVisible: _cart.isNotEmpty,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () {
              if (_cart.isNotEmpty) {
                _tabController.animateTo(1);
              }
            },
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'hold',
                child: Row(
                  children: [
                    Icon(Icons.pause_circle_outline),
                    SizedBox(width: 8),
                    Text('Hold Transaction'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history),
                    SizedBox(width: 8),
                    Text('Sales History'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag), text: 'Products'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Cart'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Sales stats banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.greenPantone.withOpacity(0.1),
                  AppTheme.amberSae.withOpacity(0.1),
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.trending_up,
                    label: 'Today\'s Sales',
                    value: '120,000 RWF',
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade300,
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.flag_outlined,
                    label: 'Target',
                    value: '${((_transactionsToday * 2550) / _salesTarget * 100).toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Products Tab
                Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search / Scan Product',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.amberSae.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner,
                                color: AppTheme.amberSae,
                              ),
                            ),
                            onPressed: () {
                              // TODO: Implement barcode scanner
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ),

                    // Category Pills
                    Consumer(
                      builder: (context, ref, child) {
                        final categoriesAsync = ref.watch(categoriesProvider);
                        return categoriesAsync.when(
                          data: (categories) {
                            final allCategories = ['All', ...categories];
                            return SizedBox(
                              height: 50,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: allCategories.length,
                                itemBuilder: (context, index) {
                                  final category = allCategories[index];
                                  final isSelected = _selectedCategory == category;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      selected: isSelected,
                                      label: Text(category),
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedCategory = category;
                                        });
                                      },
                                      backgroundColor: Colors.grey.shade100,
                                      selectedColor: AppTheme.amberSae.withOpacity(0.2),
                                      checkmarkColor: AppTheme.amberSae,
                                      labelStyle: TextStyle(
                                        color: isSelected ? AppTheme.amberDark : Colors.grey.shade700,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator())),
                          error: (error, stack) => SizedBox(
                            height: 50,
                            child: Center(child: Text('Error loading categories: $error')),
                          ),
                        );
                      },
                    ),

                    // Product List
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final productsAsync = ref.watch(productsProvider);
                          return productsAsync.when(
                            data: (products) {
                              final filteredProducts = _getFilteredProducts(products);
                              if (filteredProducts.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No products found',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];
                                  return _buildProductTile(product);
                                },
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (error, stack) => Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error loading products',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    error.toString(),
                                    style: Theme.of(context).textTheme.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => ref.refresh(productsProvider),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // Cart Tab
                _buildCartView(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _checkout,
              backgroundColor: AppTheme.amberSae,
              icon: const Icon(Icons.payment),
              label: Text('Checkout (${_cart.length})'),
            )
          : null,
    );
  }

  Widget _buildStatItem(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.amberSae),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.greenPantone,
              ),
        ),
      ],
    );
  }

  Widget _buildProductTile(Product product) {
    final inCart = _cart.any((item) => item['id'] == product.id);
    final cartQuantity = inCart
        ? _cart.firstWhere((item) => item['id'] == product.id)['quantity']
        : 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: inCart
            ? BorderSide(color: AppTheme.greenPantone, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.amberSae.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.inventory_2,
                  size: 32,
                  color: AppTheme.amberSae,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(0)} RWF',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.amberSae,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: product.stock > 20
                              ? AppTheme.greenLight
                              : product.stock > 10
                                  ? AppTheme.amberLight
                                  : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Stock: ${product.stock}',
                          style: TextStyle(
                            fontSize: 10,
                            color: product.stock > 20
                                ? AppTheme.greenDark
                                : product.stock > 10
                                    ? AppTheme.amberDark
                                    : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (inCart) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Total: ${(product.price * cartQuantity).toStringAsFixed(0)} RWF',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.greenDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Quantity controls
            if (!inCart)
              ElevatedButton.icon(
                onPressed: () => _addToCart(product),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.amberSae,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.greenLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.greenPantone, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        cartQuantity > 1 ? Icons.remove : Icons.delete_outline,
                        color: cartQuantity > 1 ? AppTheme.greenPantone : Colors.red,
                        size: 24,
                      ),
                      onPressed: () {
                        final index = _cart.indexWhere((item) => item['id'] == product.id);
                        if (index >= 0) {
                          _removeFromCart(index);
                        }
                      },
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$cartQuantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.greenPantone,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add,
                        color: AppTheme.greenPantone,
                        size: 24,
                      ),
                      onPressed: () => _addToCart(product),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartView() {
    if (_cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add products to get started',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Customer info card
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline, color: AppTheme.amberSae),
                      const SizedBox(width: 8),
                      Text(
                        'Customer Information',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customerController,
                    decoration: InputDecoration(
                      hintText: 'Customer name or phone (optional)',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Cart items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _cart.length,
            itemBuilder: (context, index) {
              final item = _cart[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Product image
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.amberLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            item['image'],
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Product info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item['price'].toStringAsFixed(0)} RWF each',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Quantity controls
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              item['quantity'] > 1 ? Icons.remove_circle : Icons.delete,
                              color: item['quantity'] > 1 ? AppTheme.amberSae : Colors.red,
                            ),
                            onPressed: () => _removeFromCart(index),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.greenLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item['quantity']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: AppTheme.greenPantone,
                            ),
                            onPressed: () {
                              setState(() {
                                if (item['quantity'] < item['stock']) {
                                  item['quantity']++;
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Not enough stock for ${item['name']}')),
                                  );
                                }
                              });
                              HapticFeedback.lightImpact();
                            },
                          ),
                        ],
                      ),
                      
                      // Item total
                      SizedBox(
                        width: 80,
                        child: Text(
                          '${(item['price'] * item['quantity']).toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.greenPantone,
                              ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Discount field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _discountController,
            keyboardType: TextInputType.number,
            onChanged: (value) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Discount (RWF)',
              prefixIcon: const Icon(Icons.local_offer),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ),

        // Cart summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSummaryRow('Subtotal', _subtotal),
              const SizedBox(height: 8),
              _buildSummaryRow('Discount', -_discount),
              const SizedBox(height: 8),
              _buildSummaryRow('Tax (18%)', _tax),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${_total.toStringAsFixed(0)} RWF',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.greenPantone,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearCart,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _checkout,
                      icon: const Icon(Icons.payment),
                      label: const Text('Checkout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.amberSae,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    final isNegative = amount < 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          '${isNegative ? '-' : ''}${amount.abs().toStringAsFixed(0)} RWF',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isNegative ? Colors.red : null,
              ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.greenLight : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.greenPantone : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.greenPantone : Colors.grey.shade600,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.greenDark : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerController.dispose();
    _discountController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}
