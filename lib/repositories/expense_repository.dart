import '../models/expense.dart';
import '../services/database_helper.dart';

class ExpenseRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _expensesKey = 'expenses';
  static const String _deletedIdsKey = 'deleted_expense_ids';

  // In-memory caches (static: repositories are instantiated in many places).
  static List<Expense>? _cache;
  static List<String>? _deletedIdsCache;

  Future<List<Expense>> getAllExpenses() async {
    final cached = _cache;
    if (cached != null) return List<Expense>.of(cached);
    try {
      final jsonData = await _storage.getData(_expensesKey);
      if (jsonData == null) {
        _cache = <Expense>[];
        return [];
      }

      final decoded = await decodeJson(jsonData);
      if (decoded is! List) {
        return [];
      }

      final expenses = <Expense>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        try {
          expenses.add(Expense.fromMap(Map<String, dynamic>.from(item)));
        } catch (e) {
          print('Skipping invalid expense record: $e');
        }
      }
      expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cache = expenses;
      return List<Expense>.of(expenses);
    } catch (e, stackTrace) {
      print('Error getting all expenses: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Saves all expenses (updates the in-memory cache first so reads are
  // instantly consistent, then persists).
  Future<bool> _saveExpenses(List<Expense> expenses) async {
    final snapshot = List<Expense>.of(expenses)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cache = snapshot;
    try {
      final jsonList = snapshot.map((expense) => expense.toMap()).toList();
      final jsonData = await encodeJson(jsonList);
      final success = await _storage.saveData(_expensesKey, jsonData);
      if (!success) {
        // Persist failed: refresh from storage on next read.
        _cache = null;
      }
      return success;
    } catch (e) {
      print('Error saving expenses: $e');
      _cache = null;
      return false;
    }
  }

  Future<Expense?> getExpenseById(String id) async {
    final expenses = await getAllExpenses();
    try {
      return expenses.firstWhere((expense) => expense.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<bool> insertExpense(Expense expense) async {
    try {
      final expenses = await getAllExpenses();
      expenses.add(expense);
      return await _saveExpenses(expenses);
    } catch (e) {
      print('Error inserting expense: $e');
      return false;
    }
  }

  Future<bool> updateExpense(Expense updatedExpense) async {
    try {
      final expenses = await getAllExpenses();
      final index =
          expenses.indexWhere((expense) => expense.id == updatedExpense.id);
      if (index == -1) {
        return false;
      }
      expenses[index] = updatedExpense;
      return await _saveExpenses(expenses);
    } catch (e) {
      print('Error updating expense: $e');
      return false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    try {
      final expenses = await getAllExpenses();
      final initialLength = expenses.length;
      expenses.removeWhere((expense) => expense.id == id);
      final success = await _saveExpenses(expenses);
      if (success && expenses.length < initialLength) {
        await addDeletedExpenseIds([id]);
      }
      return success;
    } catch (e) {
      print('Error deleting expense: $e');
      return false;
    }
  }

  Future<List<String>> getDeletedExpenseIds() async {
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

  Future<void> addDeletedExpenseIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final existing = (await getDeletedExpenseIds()).toSet();
    final before = existing.length;
    existing.addAll(ids);
    if (existing.length == before) return;
    final updated = existing.toList();
    _deletedIdsCache = updated;
    final saved =
        await _storage.saveData(_deletedIdsKey, await encodeJson(updated));
    if (!saved) _deletedIdsCache = null;
  }

  /// Returns whether any local expense was actually removed.
  Future<bool> applyDeletedExpenseIds(List<String> ids) async {
    if (ids.isEmpty) return false;
    final deletedSet = ids.toSet();
    final expenses = await getAllExpenses();
    final filtered =
        expenses.where((e) => !deletedSet.contains(e.id)).toList();
    final removed = filtered.length < expenses.length;
    if (removed) {
      await _saveExpenses(filtered);
    }
    await addDeletedExpenseIds(ids);
    return removed;
  }

  Future<List<Expense>> getExpensesByDateRange(
      DateTime start, DateTime end) async {
    final expenses = await getAllExpenses();
    return expenses.where((expense) {
      return !expense.createdAt.isBefore(start) &&
          !expense.createdAt.isAfter(end);
    }).toList();
  }

  Future<double> getTotalExpenses({
    DateTime? start,
    DateTime? end,
  }) async {
    final expenses = (start != null && end != null)
        ? await getExpensesByDateRange(start, end)
        : await getAllExpenses();
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  Future<bool> replaceAllExpenses(List<Expense> expenses) async {
    return await _saveExpenses(expenses);
  }
}
