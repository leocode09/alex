import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/product.dart';
import '../../../providers/product_provider.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';

class ProductCatalogPage extends ConsumerStatefulWidget {
  const ProductCatalogPage({super.key});

  @override
  ConsumerState<ProductCatalogPage> createState() => _ProductCatalogPageState();
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
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Restock Inventory',
            onPressed: () async {
              final allowed = await PinProtection.requirePinIfNeeded(
                context,
                isRequired: () => PinService().isPinRequiredForAdjustStock(),
                title: 'Adjust Stock',
                subtitle: 'Enter PIN to adjust stock levels',
              );
              if (!allowed) {
                return;
              }
              if (!context.mounted) {
                return;
              }
              context.push('/inventory');
            },
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage Categories',
            onPressed: () async {
              if (await PinProtection.requirePinIfNeeded(
                context,
                isRequired: () => PinService().isPinRequiredForViewCategories(),
                title: 'Categories Access',
                subtitle: 'Enter PIN to access categories',
              )) {
                if (!context.mounted) {
                  return;
                }
                context.push('/categories');
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('Name')),
              const PopupMenuItem(value: 'stock', child: Text('Stock')),
              const PopupMenuItem(value: 'price', child: Text('Price')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (await PinProtection.requirePinIfNeeded(
            context,
            isRequired: () => PinService().isPinRequiredForAddProduct(),
            title: 'Add Product',
            subtitle: 'Enter PIN to add a product',
          )) {
            if (!context.mounted) {
              return;
            }
            context.push('/products/add');
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search & Filter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 32,
                  child: categoriesAsync.when(
                    data: (categories) {
                      final allCategories = ['All', ...categories];
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: allCategories.length,
                        itemBuilder: (context, index) {
                          final category = allCategories[index];
                          final isSelected = category == 'All'
                              ? selectedCategory == null || selectedCategory.isEmpty
                              : selectedCategory == category;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                if (category == 'All') {
                                  ref.read(selectedCategoryProvider.notifier).state = null;
                                } else {
                                  ref.read(selectedCategoryProvider.notifier).state = category;
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                                  border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
              ],
            ),
          ),

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
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No products found', style: TextStyle(color: Colors.grey[500])),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final searchQuery = _searchController.text.trim();
                            if (await PinProtection.requirePinIfNeeded(
                              context,
                              isRequired: () => PinService().isPinRequiredForAddProduct(),
                              title: 'Add Product',
                              subtitle: 'Enter PIN to add a product',
                            )) {
                              if (!context.mounted) {
                                return;
                              }
                              if (searchQuery.isNotEmpty) {
                                context.push('/products/add?name=${Uri.encodeComponent(searchQuery)}');
                              } else {
                                context.push('/products/add');
                              }
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
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: sortedProducts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final product = sortedProducts[index];
                    return Dismissible(
                      key: Key(product.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        final canDelete = await PinProtection.requirePinIfNeeded(
                          context,
                          isRequired: () => PinService().isPinRequiredForDeleteProduct(),
                          title: 'Delete Product',
                          subtitle: 'Enter PIN to delete a product',
                        );
                        if (!canDelete) {
                          return false;
                        }
                        if (!context.mounted) {
                          return false;
                        }
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Product'),
                            content: Text('Are you sure you want to delete ${product.name}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) async {
                        final deleted = await ref
                            .read(productNotifierProvider.notifier)
                            .deleteProduct(product.id);
                        if (!deleted) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Failed to delete ${product.name}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${product.name} deleted')),
                          );
                        }
                      },
                      child: ListTile(
                        onTap: () async {
                          if (await PinProtection.requirePinIfNeeded(
                            context,
                            isRequired: () => PinService().isPinRequiredForViewProductDetails(),
                            title: 'Product Details',
                            subtitle: 'Enter PIN to view product details',
                          )) {
                            if (!context.mounted) {
                              return;
                            }
                            context.push('/products/${product.id}', extra: product);
                          }
                        },
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, size: 20, color: Colors.grey),
                        ),
                        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          'Stock: ${product.stock} • ${product.category}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        trailing: Text(
                          '\$${product.price.toInt()}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
