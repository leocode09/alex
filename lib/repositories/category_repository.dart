import '../models/category.dart';
import '../services/database_helper.dart';

class CategoryRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _categoriesKey = 'categories';
  static const String _deletedIdsKey = 'deleted_category_ids';

  // In-memory caches (static: repositories are instantiated in many places).
  // The cache holds the stored list; an empty stored list still yields
  // defaults from [getAllCategories], matching the uncached behavior.
  static List<Category>? _cache;
  static List<String>? _deletedIdsCache;

  // Get all categories
  Future<List<Category>> getAllCategories() async {
    final cached = _cache;
    if (cached != null) {
      if (cached.isEmpty) return _getDefaultCategories();
      return List<Category>.of(cached);
    }
    try {
      final jsonData = await _storage.getData(_categoriesKey);
      if (jsonData == null) {
        _cache = <Category>[];
        return _getDefaultCategories();
      }

      final List<dynamic> decoded = await decodeJson(jsonData);
      if (decoded.isEmpty) {
        _cache = <Category>[];
        return _getDefaultCategories();
      }

      final categories = decoded.map((json) => Category.fromMap(json)).toList();

      // Sort by name
      categories.sort((a, b) => a.name.compareTo(b.name));
      _cache = categories;
      return List<Category>.of(categories);
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

  // Save all categories (updates the in-memory cache first so reads are
  // instantly consistent, then persists).
  Future<bool> _saveCategories(List<Category> categories) async {
    final snapshot = List<Category>.of(categories)
      ..sort((a, b) => a.name.compareTo(b.name));
    _cache = snapshot;
    try {
      final jsonList = snapshot.map((c) => c.toMap()).toList();
      final jsonData = await encodeJson(jsonList);
      final success = await _storage.saveData(_categoriesKey, jsonData);
      if (!success) {
        // Persist failed: refresh from storage on next read.
        _cache = null;
      }
      return success;
    } catch (e) {
      print('Error saving categories: $e');
      _cache = null;
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

  // Delete category (records tombstone for cross-device sync propagation)
  Future<bool> deleteCategory(String id) async {
    final categories = await getAllCategories();
    final initialLength = categories.length;
    categories.removeWhere((c) => c.id == id);
    final success = await _saveCategories(categories);
    if (success && categories.length < initialLength) {
      await addDeletedCategoryIds([id]);
    }
    return success;
  }

  Future<List<String>> getDeletedCategoryIds() async {
    final cached = _deletedIdsCache;
    if (cached != null) return List<String>.of(cached);
    final jsonData = await _storage.getData(_deletedIdsKey);
    if (jsonData == null) {
      _deletedIdsCache = <String>[];
      return [];
    }
    try {
      final List<dynamic> decoded = await decodeJson(jsonData);
      final ids = List<String>.of(decoded.cast<String>());
      _deletedIdsCache = ids;
      return List<String>.of(ids);
    } catch (e) {
      return [];
    }
  }

  Future<void> addDeletedCategoryIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final existing = (await getDeletedCategoryIds()).toSet();
    final before = existing.length;
    existing.addAll(ids);
    if (existing.length == before) return;
    final updated = existing.toList();
    _deletedIdsCache = updated;
    final saved =
        await _storage.saveData(_deletedIdsKey, await encodeJson(updated));
    if (!saved) _deletedIdsCache = null;
  }

  /// Returns whether any local category was actually removed.
  Future<bool> applyDeletedCategoryIds(List<String> ids) async {
    if (ids.isEmpty) return false;
    final deletedSet = ids.toSet();
    final categories = await getAllCategories();
    final filtered =
        categories.where((c) => !deletedSet.contains(c.id)).toList();
    final removed = filtered.length < categories.length;
    if (removed) {
      await _saveCategories(filtered);
    }
    await addDeletedCategoryIds(ids);
    return removed;
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
