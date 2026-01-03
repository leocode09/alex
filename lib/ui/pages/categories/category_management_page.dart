import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/category.dart';
import '../../../providers/category_provider.dart';
import '../../themes/app_theme.dart';

class CategoryManagementPage extends ConsumerStatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  ConsumerState<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends ConsumerState<CategoryManagementPage> {
  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        backgroundColor: AppTheme.amberSae,
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No categories yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first category',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.amberLight,
                    child: Icon(
                      _getIconData(category.icon),
                      color: AppTheme.amberDark,
                    ),
                  ),
                  title: Text(
                    category.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (category.description != null)
                        Text(category.description!),
                      const SizedBox(height: 4),
                      Text(
                        '${category.productCount} products',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showAddEditDialog(category: category);
                      } else if (value == 'delete') {
                        _confirmDelete(category);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(categoriesListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppTheme.amberSae,
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'local_cafe':
        return Icons.local_cafe;
      case 'restaurant':
        return Icons.restaurant;
      case 'home':
        return Icons.home;
      case 'sports':
        return Icons.sports;
      case 'devices':
        return Icons.devices;
      case 'checkroom':
        return Icons.checkroom;
      case 'local_grocery_store':
        return Icons.local_grocery_store;
      case 'shopping_bag':
        return Icons.shopping_bag;
      default:
        return Icons.category;
    }
  }

  void _showAddEditDialog({Category? category}) {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController = TextEditingController(text: category?.description ?? '');
    String selectedIcon = category?.icon ?? 'category';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'Edit Category' : 'Add Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedIcon,
                  decoration: const InputDecoration(
                    labelText: 'Icon',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'category',
                      child: Row(
                        children: [
                          Icon(Icons.category, color: AppTheme.amberSae),
                          const SizedBox(width: 8),
                          const Text('Category'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'local_cafe',
                      child: Row(
                        children: [
                          Icon(Icons.local_cafe, color: AppTheme.amberSae),
                          const SizedBox(width: 8),
                          const Text('Beverages'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'restaurant',
                      child: Row(
                        children: [
                          Icon(Icons.restaurant, color: AppTheme.amberSae),
                          const SizedBox(width: 8),
                          const Text('Food'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'home',
                      child: Row(
                        children: [
                          Icon(Icons.home, color: AppTheme.amberSae),
                          const SizedBox(width: 8),
                          const Text('Household'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'checkroom',
                      child: Row(
                        children: [
                          Icon(Icons.checkroom, color: AppTheme.amberSae),
                          const SizedBox(width: 8),
                          const Text('Clothing'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'devices',
                      child: Row(
                        children: [
                          Icon(Icons.devices, color: AppTheme.amberSae),
                          const SizedBox(width: 8),
                          const Text('Electronics'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'sports',
                      child: Row(
                        children: [
                          Icon(Icons.sports, color: AppTheme.amberSae),
                          const SizedBox(width: 8),
                          const Text('Sports'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'local_grocery_store',
                      child: Row(
                        children: [
                          Icon(Icons.local_grocery_store, color: AppTheme.amberSae),
                          const SizedBox(width: 8),
                          const Text('Groceries'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'shopping_bag',
                      child: Row(
                        children: [
                          Icon(Icons.shopping_bag, color: AppTheme.amberSae),
                          const SizedBox(width: 8),
                          const Text('Shopping'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedIcon = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a category name')),
                  );
                  return;
                }

                // Check if name exists
                final exists = await ref.read(categoriesListProvider.notifier).categoryNameExists(
                      name,
                      excludeId: category?.id,
                    );
                if (exists) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Category name already exists')),
                    );
                  }
                  return;
                }

                final newCategory = Category(
                  id: category?.id ?? 'cat_${const Uuid().v4()}',
                  name: name,
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                  icon: selectedIcon,
                  productCount: category?.productCount ?? 0,
                  createdAt: category?.createdAt,
                  updatedAt: DateTime.now(),
                );

                final success = isEditing
                    ? await ref.read(categoriesListProvider.notifier).updateCategory(newCategory)
                    : await ref.read(categoriesListProvider.notifier).addCategory(newCategory);

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? isEditing
                                ? 'Category updated'
                                : 'Category added'
                            : 'Failed to save category',
                      ),
                      backgroundColor: success ? AppTheme.greenPantone : Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.amberSae,
              ),
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Category category) {
    if (category.productCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete category with ${category.productCount} products. Remove products first.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await ref.read(categoriesListProvider.notifier).deleteCategory(category.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Category deleted' : 'Failed to delete category'),
                    backgroundColor: success ? AppTheme.greenPantone : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
