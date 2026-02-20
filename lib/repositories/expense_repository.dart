import 'dart:convert';

import '../models/expense.dart';
import '../services/database_helper.dart';

class ExpenseRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _expensesKey = 'expenses';

  Future<List<Expense>> getAllExpenses() async {
    try {
      final jsonData = await _storage.getData(_expensesKey);
      if (jsonData == null) return [];

      final decoded = jsonDecode(jsonData);
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
      return expenses;
    } catch (e, stackTrace) {
      print('Error getting all expenses: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<bool> _saveExpenses(List<Expense> expenses) async {
    try {
      final jsonList = expenses.map((expense) => expense.toMap()).toList();
      final jsonData = jsonEncode(jsonList);
      return await _storage.saveData(_expensesKey, jsonData);
    } catch (e) {
      print('Error saving expenses: $e');
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
      expenses.removeWhere((expense) => expense.id == id);
      return await _saveExpenses(expenses);
    } catch (e) {
      print('Error deleting expense: $e');
      return false;
    }
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
