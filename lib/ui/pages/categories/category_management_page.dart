import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/category.dart';
import '../../../providers/category_provider.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';

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
        title: const Text('Categories', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (await PinProtection.requirePinIfNeeded(
            context,
            isRequired: () => PinService().isPinRequiredForAddCategory(),
            title: 'Add Category',
            subtitle: 'Enter PIN to add a category',
          )) {
            _showAddEditDialog();
          }
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('No categories found'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getIconData(category.icon), color: Colors.black87, size: 20),
                ),
                title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  '${category.productCount} products',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                trailing: PopupMenuButton(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final allowed = await PinProtection.requirePinIfNeeded(
                        context,
                        isRequired: () => PinService().isPinRequiredForEditCategory(),
                        title: 'Edit Category',
                        subtitle: 'Enter PIN to edit a category',
                      );
                      if (allowed && mounted) {
                        _showAddEditDialog(category: category);
                      }
                    } else if (value == 'delete') {
                      final allowed = await PinProtection.requirePinIfNeeded(
                        context,
                        isRequired: () => PinService().isPinRequiredForDeleteCategory(),
                        title: 'Delete Category',
                        subtitle: 'Enter PIN to delete a category',
                      );
                      if (allowed && mounted) {
                        _confirmDelete(category);
                      }
                    }
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'local_cafe': return Icons.local_cafe;
      case 'restaurant': return Icons.restaurant;
      case 'home': return Icons.home;
      case 'sports': return Icons.sports;
      case 'devices': return Icons.devices;
      case 'checkroom': return Icons.checkroom;
      case 'local_grocery_store': return Icons.local_grocery_store;
      case 'shopping_bag': return Icons.shopping_bag;
      default: return Icons.category;
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
          title: Text(isEditing ? 'Edit Category' : 'Add Category', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedIcon,
                  decoration: InputDecoration(
                    labelText: 'Icon',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                  items: [
                    _buildIconItem('category', 'Category', Icons.category),
                    _buildIconItem('local_cafe', 'Beverages', Icons.local_cafe),
                    _buildIconItem('restaurant', 'Food', Icons.restaurant),
                    _buildIconItem('home', 'Household', Icons.home),
                    _buildIconItem('checkroom', 'Clothing', Icons.checkroom),
                    _buildIconItem('devices', 'Electronics', Icons.devices),
                    _buildIconItem('sports', 'Sports', Icons.sports),
                    _buildIconItem('local_grocery_store', 'Groceries', Icons.local_grocery_store),
                    _buildIconItem('shopping_bag', 'Shopping', Icons.shopping_bag),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => selectedIcon = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

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
                      content: Text(success ? (isEditing ? 'Updated' : 'Added') : 'Failed'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        ),
      ),
    );
  }

  DropdownMenuItem<String> _buildIconItem(String value, String label, IconData icon) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  void _confirmDelete(Category category) {
    if (category.productCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot delete category with ${category.productCount} products.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final success = await ref.read(categoriesListProvider.notifier).deleteCategory(category.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? 'Deleted' : 'Failed'), backgroundColor: success ? Colors.green : Colors.red),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
