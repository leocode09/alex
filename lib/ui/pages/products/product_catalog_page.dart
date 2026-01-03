import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/product.dart';
import '../../../providers/product_provider.dart';
import '../../themes/app_theme.dart';

class ProductCatalogPage extends ConsumerStatefulWidget {
  const ProductCatalogPage({super.key});

  @override
  ConsumerState<ProductCatalogPage> createState() =>
      _ProductCatalogPageState();
}

class _ProductCatalogPageState extends ConsumerState<ProductCatalogPage> {
  final _searchController = TextEditingController();
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(searchQueryProvider.notifier).state = _searchController.text;
    });
  }

  List<Product> _sortProducts(List<Product> products) {
    final sorted = List<Product>.from(products);
    if (_sortBy == 'name') {
      sorted.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortBy == 'stock') {
      sorted.sort((a, b) => a.stock.compareTo(b.stock));
    } else if (_sortBy == 'price') {
      sorted.sort((a, b) => a.price.compareTo(b.price));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final filteredProductsAsync = ref.watch(filteredProductsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final totalCountAsync = ref.watch(totalProductsCountProvider);
    final lowStockAsync = ref.watch(lowStockProductsProvider);
    final totalValueAsync = ref.watch(totalInventoryValueProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product Catalog'),
            totalCountAsync.when(
              data: (count) => Text(
                '$count products',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              loading: () => Text(
                'Loading...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha,
                        color: _sortBy == 'name' ? AppTheme.amberSae : null),
                    const SizedBox(width: 8),
                    const Text('Sort by Name'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'stock',
                child: Row(
                  children: [
                    Icon(Icons.inventory,
                        color: _sortBy == 'stock' ? AppTheme.amberSae : null),
                    const SizedBox(width: 8),
                    const Text('Sort by Stock'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'price',
                child: Row(
                  children: [
                    Icon(Icons.attach_money,
                        color: _sortBy == 'price' ? AppTheme.amberSae : null),
                    const SizedBox(width: 8),
                    const Text('Sort by Price'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Manage Categories',
            onPressed: () => context.push('/categories'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Stats Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.amberSae.withOpacity(0.1),
                  AppTheme.greenPantone.withOpacity(0.1),
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: totalCountAsync.when(
                    data: (count) => _buildStatCard(
                      context,
                      icon: Icons.inventory_2_outlined,
                      label: 'Total Products',
                      value: '$count',
                      color: AppTheme.amberSae,
                    ),
                    loading: () => _buildStatCard(
                      context,
                      icon: Icons.inventory_2_outlined,
                      label: 'Total Products',
                      value: '...',
                      color: AppTheme.amberSae,
                    ),
                    error: (_, __) => _buildStatCard(
                      context,
                      icon: Icons.inventory_2_outlined,
                      label: 'Total Products',
                      value: '0',
                      color: AppTheme.amberSae,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: lowStockAsync.when(
                    data: (products) => _buildStatCard(
                      context,
                      icon: Icons.warning_amber_rounded,
                      label: 'Low Stock',
                      value: '${products.length}',
                      color: Colors.orange,
                    ),
                    loading: () => _buildStatCard(
                      context,
                      icon: Icons.warning_amber_rounded,
                      label: 'Low Stock',
                      value: '...',
                      color: Colors.orange,
                    ),
                    error: (_, __) => _buildStatCard(
                      context,
                      icon: Icons.warning_amber_rounded,
                      label: 'Low Stock',
                      value: '0',
                      color: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: totalValueAsync.when(
                    data: (value) => _buildStatCard(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Total Value',
                      value: '${(value / 1000).toStringAsFixed(0)}K',
                      color: AppTheme.greenPantone,
                    ),
                    loading: () => _buildStatCard(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Total Value',
                      value: '...',
                      color: AppTheme.greenPantone,
                    ),
                    error: (_, __) => _buildStatCard(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Total Value',
                      value: '0',
                      color: AppTheme.greenPantone,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by name or barcode',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),

          // Category Pills
          SizedBox(
            height: 50,
            child: categoriesAsync.when(
              data: (categories) {
                final allCategories = ['All', ...categories];
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: allCategories.length,
                  itemBuilder: (context, index) {
                    final category = allCategories[index];
                    final isSelected = category == 'All'
                        ? selectedCategory == 'All'
                        : selectedCategory == category;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(category),
                        onSelected: (selected) {
                          if (category == 'All') {
                            ref.read(selectedCategoryProvider.notifier).state =
                                'All';
                          } else {
                            ref.read(selectedCategoryProvider.notifier).state =
                                category;
                          }
                        },
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: AppTheme.amberSae.withOpacity(0.2),
                        checkmarkColor: AppTheme.amberSae,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppTheme.amberDark
                              : Colors.grey.shade700,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
            ),
          ),

          const SizedBox(height: 8),

          // Product List
          Expanded(
            child: filteredProductsAsync.when(
              data: (products) {
                final sortedProducts = _sortProducts(products);
                if (sortedProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products found',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filters',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade500,
                                  ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: sortedProducts.length,
                  itemBuilder: (context, index) {
                    final product = sortedProducts[index];
                    return _buildProductTile(product);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 80, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading products',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.red.shade600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(filteredProductsProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/product/add'),
        backgroundColor: AppTheme.amberSae,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(Product product) {
    final stockValue = (product.price * product.stock);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: product.stock > 50
                                ? AppTheme.greenLight
                                : product.stock > 20
                                    ? AppTheme.amberLight
                                    : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${product.stock} in stock',
                            style: TextStyle(
                              fontSize: 11,
                              color: product.stock > 50
                                  ? AppTheme.greenDark
                                  : product.stock > 20
                                      ? AppTheme.amberDark
                                      : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${product.price.toStringAsFixed(0)} RWF',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.amberSae,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (product.category != null) ...[
                          Icon(Icons.category_outlined,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            product.category!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Value: ${stockValue.toStringAsFixed(0)} RWF',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
