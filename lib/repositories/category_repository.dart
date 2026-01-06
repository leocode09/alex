import 'dart:convert';
import '../models/category.dart';
import '../services/database_helper.dart';

class CategoryRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _categoriesKey = 'categories';

  // Get all categories
  Future<List<Category>> getAllCategories() async {
    try {
      final jsonData = await _storage.getData(_categoriesKey);
      if (jsonData == null) return _getDefaultCategories();
      
      final List<dynamic> decoded = jsonDecode(jsonData);
      if (decoded.isEmpty) return _getDefaultCategories();
      
      final categories = decoded.map((json) => Category.fromMap(json)).toList();
      
      // Sort by name
      categories.sort((a, b) => a.name.compareTo(b.name));
      return categories;
    } catch (e) {
      print('Error getting categories: $e');
      return _getDefaultCategories();
    }
  }

  // Get default categories
  List<Category> _getDefaultCategories() {
    final now = DateTime.now();
    return [
      Category(
        id: 'cat_beverages',
        name: 'Beverages',
        description: 'Drinks and beverages',
        icon: 'local_cafe',
        createdAt: now,
        updatedAt: now,
      ),
      Category(
        id: 'cat_food',
        name: 'Food',
        description: 'Food items and groceries',
        icon: 'restaurant',
        createdAt: now,
        updatedAt: now,
      ),
      Category(
        id: 'cat_household',
        name: 'Household',
        description: 'Household items and supplies',
        icon: 'home',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  // Save all categories
  Future<bool> _saveCategories(List<Category> categories) async {
    try {
      final jsonList = categories.map((c) => c.toMap()).toList();
      final jsonData = jsonEncode(jsonList);
      return await _storage.saveData(_categoriesKey, jsonData);
    } catch (e) {
      print('Error saving categories: $e');
      return false;
    }
  }

  // Get category by ID
  Future<Category?> getCategoryById(String id) async {
    final categories = await getAllCategories();
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get category by name
  Future<Category?> getCategoryByName(String name) async {
    final categories = await getAllCategories();
    try {
      return categories.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // Check if category name exists (for validation)
  Future<bool> categoryNameExists(String name, {String? excludeId}) async {
    final categories = await getAllCategories();
    return categories.any(
      (c) => c.name.toLowerCase() == name.toLowerCase() && c.id != excludeId,
    );
  }

  // Insert category
  Future<bool> insertCategory(Category category) async {
    final categories = await getAllCategories();
    categories.add(category);
    return await _saveCategories(categories);
  }

  // Update category
  Future<bool> updateCategory(Category category) async {
    final categories = await getAllCategories();
    final index = categories.indexWhere((c) => c.id == category.id);
    
    if (index == -1) return false;
    
    categories[index] = category;
    return await _saveCategories(categories);
  }

  // Delete category
  Future<bool> deleteCategory(String id) async {
    final categories = await getAllCategories();
    categories.removeWhere((c) => c.id == id);
    return await _saveCategories(categories);
  }

  // Initialize default categories if none exist
  Future<void> initializeDefaultCategories() async {
    final categories = await getAllCategories();
    if (categories.isEmpty) {
      final defaults = _getDefaultCategories();
      await _saveCategories(defaults);
    }
  }

  // Get category names only (for dropdown)
  Future<List<String>> getCategoryNames() async {
    final categories = await getAllCategories();
    return categories.map((c) => c.name).toList();
  }

  // Replace all categories (for sync)
  Future<bool> replaceAllCategories(List<Category> categories) async {
    return await _saveCategories(categories);
  }
}
