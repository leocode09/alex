import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  static const String _deletedAccountIdsKey = 'deleted_money_account_ids';

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
      if (kDebugMode) {
        debugPrint('Error loading money accounts: $e');
        debugPrint('Stack trace: $stackTrace');
      }
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
      if (kDebugMode) {
        debugPrint('Error loading money history: $e');
        debugPrint('Stack trace: $stackTrace');
      }
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
      note: () => note?.trim().isEmpty ?? true ? null : note!.trim(),
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
    await addDeletedMoneyAccountIds([accountId]);

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
      if (kDebugMode) {
        debugPrint('Error saving money accounts: $e');
      }
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
      if (kDebugMode) {
        debugPrint('Error saving money history: $e');
      }
      return false;
    }
  }

  Future<bool> _appendHistory(AccountHistoryRecord record) async {
    final history = await _readHistory();
    history.add(record);
    return _saveHistory(history);
  }

  Future<bool> replaceAllAccounts(List<MoneyAccount> accounts) async {
    return _saveAccounts(accounts);
  }

  Future<bool> replaceAllHistory(List<AccountHistoryRecord> history) async {
    return _saveHistory(history);
  }

  Future<List<String>> getDeletedMoneyAccountIds() async {
    final jsonData = await _storage.getData(_deletedAccountIdsKey);
    if (jsonData == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonData);
      return decoded.cast<String>();
    } catch (e) {
      return [];
    }
  }

  Future<void> addDeletedMoneyAccountIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final existing = (await getDeletedMoneyAccountIds()).toSet();
    existing.addAll(ids);
    await _storage.saveData(
        _deletedAccountIdsKey, jsonEncode(existing.toList()));
  }

  Future<void> applyDeletedMoneyAccountIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final deletedSet = ids.toSet();
    final accounts = await _readAccounts();
    final filtered =
        accounts.where((a) => !deletedSet.contains(a.id)).toList();
    if (filtered.length < accounts.length) {
      await _saveAccounts(filtered);
    }
    await addDeletedMoneyAccountIds(ids);
  }

  Future<MoneyActionResult> updateHistoryRecord({
    required String recordId,
    double? amount,
    String? note,
    DateTime? createdAt,
  }) async {
    final history = await _readHistory();
    final currentAccounts = await _readAccounts();
    final index = history.indexWhere((r) => r.id == recordId);
    if (index == -1) {
      return MoneyActionResult.fail('History record not found.');
    }

    final existing = history[index];
    final updated = existing.copyWith(
      amount: amount ?? existing.amount,
      note: note != null ? () => note.trim().isEmpty ? null : note.trim() : null,
      createdAt: createdAt ?? existing.createdAt,
    );

    history[index] = updated;
    history.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final replayResult = _replayHistory(history, currentAccounts);
    if (replayResult == null) {
      return MoneyActionResult.fail(
        'Cannot apply edit: would result in invalid state (e.g. negative balance).',
      );
    }

    final savedHistory = await _saveHistory(replayResult.records);
    if (!savedHistory) {
      return MoneyActionResult.fail('Failed to save history.');
    }
    final savedAccounts = await _saveAccounts(replayResult.accounts);
    if (!savedAccounts) {
      return MoneyActionResult.fail('Failed to save accounts.');
    }

    return MoneyActionResult.ok('History record updated.');
  }

  _ReplayResult? _replayHistory(
    List<AccountHistoryRecord> records,
    List<MoneyAccount> currentAccounts,
  ) {
    final accountBalances = <String, double>{};
    final updatedRecords = <AccountHistoryRecord>[];

    for (final record in records) {
      final currentBalance = accountBalances[record.accountId] ?? 0.0;

      switch (record.action) {
        case MoneyHistoryAction.accountCreated:
          final balance = record.amount < 0 ? 0.0 : record.amount;
          accountBalances[record.accountId] = balance;
          updatedRecords.add(record.copyWith(
            balanceBefore: 0,
            balanceAfter: balance,
          ));
          break;
        case MoneyHistoryAction.accountUpdated:
          updatedRecords.add(record.copyWith(
            balanceBefore: currentBalance,
            balanceAfter: currentBalance,
          ));
          break;
        case MoneyHistoryAction.accountDeleted:
          updatedRecords.add(record.copyWith(
            balanceBefore: currentBalance,
            balanceAfter: 0,
          ));
          accountBalances[record.accountId] = 0.0;
          break;
        case MoneyHistoryAction.moneyAdded:
          final addAmount = record.amount < 0 ? 0.0 : record.amount;
          final newBalance = currentBalance + addAmount;
          accountBalances[record.accountId] = newBalance;
          updatedRecords.add(record.copyWith(
            amount: addAmount,
            balanceBefore: currentBalance,
            balanceAfter: newBalance,
          ));
          break;
        case MoneyHistoryAction.moneyRemoved:
          final removeAmount = record.amount < 0 ? 0.0 : record.amount;
          final nextBalance = currentBalance - removeAmount;
          if (nextBalance < 0) return null;
          accountBalances[record.accountId] = nextBalance;
          updatedRecords.add(record.copyWith(
            amount: removeAmount,
            balanceBefore: currentBalance,
            balanceAfter: nextBalance,
          ));
          break;
      }
    }

    final accounts = currentAccounts.map((acc) {
      final finalBalance = accountBalances[acc.id] ?? 0.0;
      return acc.copyWith(balance: finalBalance);
    }).toList();

    accounts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _ReplayResult(accounts: accounts, records: updatedRecords);
  }
}

class _ReplayResult {
  final List<MoneyAccount> accounts;
  final List<AccountHistoryRecord> records;

  _ReplayResult({required this.accounts, required this.records});
}
