import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';
import 'product_provider.dart';
import 'sync_events_provider.dart';

// Category repository provider
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

// Categories list provider
final categoriesListProvider = StateNotifierProvider<CategoriesNotifier, AsyncValue<List<Category>>>((ref) {
  return CategoriesNotifier(ref);
});

class CategoriesNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  final Ref _ref;

  CategoriesNotifier(this._ref) : super(const AsyncValue.loading()) {
    _ref.listen(syncEventsProvider, (previous, next) {
      if (next.hasValue) {
        loadCategories();
      }
    });
    loadCategories();
  }

  Future<void> loadCategories() async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(categoryRepositoryProvider);
      final productRepository = _ref.read(productRepositoryProvider);
      
      final categories = await repository.getAllCategories();
      final products = await productRepository.getAllProducts();
      
      // Update product count for each category
      final updatedCategories = categories.map((category) {
        final count = products.where((p) => p.category == category.name).length;
        return category.copyWith(productCount: count);
      }).toList();
      
      state = AsyncValue.data(updatedCategories);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> addCategory(Category category) async {
    try {
      final repository = _ref.read(categoryRepositoryProvider);
      final success = await repository.insertCategory(category);
      if (success) {
        await loadCategories();
      }
      return success;
    } catch (e) {
      print('Error adding category: $e');
      return false;
    }
  }

  Future<bool> updateCategory(Category category) async {
    try {
      final repository = _ref.read(categoryRepositoryProvider);
      final success = await repository.updateCategory(category);
      if (success) {
        await loadCategories();
      }
      return success;
    } catch (e) {
      print('Error updating category: $e');
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      final repository = _ref.read(categoryRepositoryProvider);
      final success = await repository.deleteCategory(id);
      if (success) {
        await loadCategories();
      }
      return success;
    } catch (e) {
      print('Error deleting category: $e');
      return false;
    }
  }

  Future<bool> categoryNameExists(String name, {String? excludeId}) async {
    final repository = _ref.read(categoryRepositoryProvider);
    return await repository.categoryNameExists(name, excludeId: excludeId);
  }
}

// Category names provider (for dropdowns)
final categoryNamesProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(categoryRepositoryProvider);
  return await repository.getCategoryNames();
});

// Single category provider
final categoryProvider = FutureProvider.family<Category?, String>((ref, id) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(categoryRepositoryProvider);
  return await repository.getCategoryById(id);
});
