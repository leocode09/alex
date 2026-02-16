import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/account_history_record.dart';
import '../models/money_account.dart';
import '../services/database_helper.dart';

class MoneyActionResult {
  final bool success;
  final String message;

  const MoneyActionResult._({
    required this.success,
    required this.message,
  });

  factory MoneyActionResult.ok(String message) {
    return MoneyActionResult._(success: true, message: message);
  }

  factory MoneyActionResult.fail(String message) {
    return MoneyActionResult._(success: false, message: message);
  }
}

class MoneyRepository {
  final StorageHelper _storage = StorageHelper();
  final Uuid _uuid = const Uuid();

  static const String _accountsKey = 'money_accounts';
  static const String _historyKey = 'money_account_history';

  Future<List<MoneyAccount>> getAllAccounts() async {
    try {
      final jsonData = await _storage.getData(_accountsKey);
      if (jsonData == null) {
        return [];
      }
      final decoded = jsonDecode(jsonData) as List<dynamic>;
      final accounts = decoded
          .map((item) => MoneyAccount.fromMap(item as Map<String, dynamic>))
          .toList();
      accounts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return accounts;
    } catch (e, stackTrace) {
      print('Error loading money accounts: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<double> getTotalBalance() async {
    final accounts = await getAllAccounts();
    return accounts.fold<double>(0, (sum, account) => sum + account.balance);
  }

  Future<List<AccountHistoryRecord>> getAllHistory() async {
    try {
      final records = await _readHistory();
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    } catch (e, stackTrace) {
      print('Error loading money history: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<AccountHistoryRecord>> getHistoryForAccount(
      String accountId) async {
    final history = await getAllHistory();
    return history.where((record) => record.accountId == accountId).toList();
  }

  Future<MoneyActionResult> createAccount({
    required String name,
    double openingBalance = 0,
    String? note,
  }) async {
    final trimmedName = name.trim();
    final sanitizedBalance = openingBalance < 0 ? -1 : openingBalance;
    if (trimmedName.isEmpty) {
      return MoneyActionResult.fail('Account name is required.');
    }
    if (sanitizedBalance < 0) {
      return MoneyActionResult.fail('Opening balance cannot be negative.');
    }

    final accounts = await _readAccounts();
    final duplicate = accounts.any(
      (account) => account.name.toLowerCase() == trimmedName.toLowerCase(),
    );
    if (duplicate) {
      return MoneyActionResult.fail('Account name already exists.');
    }

    final now = DateTime.now();
    final account = MoneyAccount(
      id: 'acc_${_uuid.v4()}',
      name: trimmedName,
      balance: openingBalance,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      createdAt: now,
      updatedAt: now,
    );

    accounts.add(account);
    final savedAccounts = await _saveAccounts(accounts);
    if (!savedAccounts) {
      return MoneyActionResult.fail('Failed to save account.');
    }

    final historyRecord = AccountHistoryRecord(
      id: 'mh_${_uuid.v4()}',
      accountId: account.id,
      accountName: account.name,
      action: MoneyHistoryAction.accountCreated,
      amount: openingBalance,
      balanceBefore: 0,
      balanceAfter: openingBalance,
      note: account.note,
      createdAt: now,
    );
    final savedHistory = await _appendHistory(historyRecord);
    if (!savedHistory) {
      return MoneyActionResult.fail(
          'Account created, but history was not saved.');
    }

    return MoneyActionResult.ok('Account created successfully.');
  }

  Future<MoneyActionResult> updateAccount({
    required String accountId,
    required String name,
    String? note,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return MoneyActionResult.fail('Account name is required.');
    }

    final accounts = await _readAccounts();
    final index = accounts.indexWhere((account) => account.id == accountId);
    if (index == -1) {
      return MoneyActionResult.fail('Account not found.');
    }

    final duplicate = accounts.any(
      (account) =>
          account.id != accountId &&
          account.name.toLowerCase() == trimmedName.toLowerCase(),
    );
    if (duplicate) {
      return MoneyActionResult.fail('Another account already uses this name.');
    }

    final existing = accounts[index];
    final updated = existing.copyWith(
      name: trimmedName,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      updatedAt: DateTime.now(),
    );
    accounts[index] = updated;

    final savedAccounts = await _saveAccounts(accounts);
    if (!savedAccounts) {
      return MoneyActionResult.fail('Failed to update account.');
    }

    final changes = <String>[];
    if (existing.name != updated.name) {
      changes.add('Name: "${existing.name}" -> "${updated.name}"');
    }
    if ((existing.note ?? '') != (updated.note ?? '')) {
      changes.add('Note updated');
    }

    final historyRecord = AccountHistoryRecord(
      id: 'mh_${_uuid.v4()}',
      accountId: updated.id,
      accountName: updated.name,
      action: MoneyHistoryAction.accountUpdated,
      amount: 0,
      balanceBefore: existing.balance,
      balanceAfter: updated.balance,
      note: changes.isEmpty ? 'Account details updated' : changes.join(' | '),
    );
    await _appendHistory(historyRecord);

    return MoneyActionResult.ok('Account updated successfully.');
  }

  Future<MoneyActionResult> deleteAccount(String accountId) async {
    final accounts = await _readAccounts();
    final index = accounts.indexWhere((account) => account.id == accountId);
    if (index == -1) {
      return MoneyActionResult.fail('Account not found.');
    }

    final account = accounts[index];
    accounts.removeAt(index);
    final savedAccounts = await _saveAccounts(accounts);
    if (!savedAccounts) {
      return MoneyActionResult.fail('Failed to delete account.');
    }

    final historyRecord = AccountHistoryRecord(
      id: 'mh_${_uuid.v4()}',
      accountId: account.id,
      accountName: account.name,
      action: MoneyHistoryAction.accountDeleted,
      amount: 0,
      balanceBefore: account.balance,
      balanceAfter: 0,
      note: 'Account deleted',
    );
    await _appendHistory(historyRecord);

    return MoneyActionResult.ok('Account deleted successfully.');
  }

  Future<MoneyActionResult> addMoney({
    required String accountId,
    required double amount,
    String? note,
  }) async {
    if (amount <= 0) {
      return MoneyActionResult.fail('Amount must be greater than zero.');
    }
    return _updateBalance(
      accountId: accountId,
      amount: amount,
      action: MoneyHistoryAction.moneyAdded,
      note: note,
      successMessage: 'Money added successfully.',
    );
  }

  Future<MoneyActionResult> removeMoney({
    required String accountId,
    required double amount,
    String? note,
  }) async {
    if (amount <= 0) {
      return MoneyActionResult.fail('Amount must be greater than zero.');
    }
    return _updateBalance(
      accountId: accountId,
      amount: -amount,
      action: MoneyHistoryAction.moneyRemoved,
      note: note,
      successMessage: 'Money removed successfully.',
    );
  }

  Future<MoneyActionResult> _updateBalance({
    required String accountId,
    required double amount,
    required MoneyHistoryAction action,
    required String successMessage,
    String? note,
  }) async {
    final accounts = await _readAccounts();
    final index = accounts.indexWhere((account) => account.id == accountId);
    if (index == -1) {
      return MoneyActionResult.fail('Account not found.');
    }

    final current = accounts[index];
    final nextBalance = current.balance + amount;
    if (nextBalance < 0) {
      return MoneyActionResult.fail(
          'Insufficient funds. Balance cannot go below zero.');
    }

    final updated = current.copyWith(
      balance: nextBalance,
      updatedAt: DateTime.now(),
    );
    accounts[index] = updated;

    final savedAccounts = await _saveAccounts(accounts);
    if (!savedAccounts) {
      return MoneyActionResult.fail('Failed to update account balance.');
    }

    final historyRecord = AccountHistoryRecord(
      id: 'mh_${_uuid.v4()}',
      accountId: updated.id,
      accountName: updated.name,
      action: action,
      amount: amount.abs(),
      balanceBefore: current.balance,
      balanceAfter: updated.balance,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
    );
    final savedHistory = await _appendHistory(historyRecord);
    if (!savedHistory) {
      return MoneyActionResult.fail(
          'Balance updated, but history was not saved.');
    }

    return MoneyActionResult.ok(successMessage);
  }

  Future<List<MoneyAccount>> _readAccounts() async {
    final jsonData = await _storage.getData(_accountsKey);
    if (jsonData == null) {
      return [];
    }
    final decoded = jsonDecode(jsonData) as List<dynamic>;
    return decoded
        .map((item) => MoneyAccount.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> _saveAccounts(List<MoneyAccount> accounts) async {
    try {
      final jsonData =
          jsonEncode(accounts.map((account) => account.toMap()).toList());
      return await _storage.saveData(_accountsKey, jsonData);
    } catch (e) {
      print('Error saving money accounts: $e');
      return false;
    }
  }

  Future<List<AccountHistoryRecord>> _readHistory() async {
    final jsonData = await _storage.getData(_historyKey);
    if (jsonData == null) {
      return [];
    }
    final decoded = jsonDecode(jsonData) as List<dynamic>;
    return decoded
        .map((item) =>
            AccountHistoryRecord.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> _saveHistory(List<AccountHistoryRecord> records) async {
    try {
      final jsonData =
          jsonEncode(records.map((record) => record.toMap()).toList());
      return await _storage.saveData(_historyKey, jsonData);
    } catch (e) {
      print('Error saving money history: $e');
      return false;
    }
  }

  Future<bool> _appendHistory(AccountHistoryRecord record) async {
    final history = await _readHistory();
    history.add(record);
    return _saveHistory(history);
  }
}
