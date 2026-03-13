import 'package:alex/models/account_history_record.dart';
import 'package:alex/repositories/money_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MoneyRepository', () {
    late MoneyRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      repository = MoneyRepository();
    });

    test('updateHistoryRecord updates note and replays correctly', () async {
      final createResult = await repository.createAccount(
        name: 'Test Account Note',
        openingBalance: 100,
        note: 'Initial',
      );
      expect(createResult.success, isTrue);

      final addResult = await repository.addMoney(
        accountId: (await repository.getAllAccounts()).first.id,
        amount: 50,
        note: 'Deposit',
      );
      expect(addResult.success, isTrue);

      final history = await repository.getAllHistory();
      expect(history.length, 2);

      final addRecord = history.firstWhere(
        (r) => r.action == MoneyHistoryAction.moneyAdded,
      );

      final updateResult = await repository.updateHistoryRecord(
        recordId: addRecord.id,
        note: 'Updated deposit note',
      );
      expect(updateResult.success, isTrue);

      final updatedHistory = await repository.getAllHistory();
      final updatedRecord = updatedHistory.firstWhere(
        (r) => r.id == addRecord.id,
      );
      expect(updatedRecord.note, 'Updated deposit note');
      expect(updatedRecord.amount, 50);

      final accounts = await repository.getAllAccounts();
      expect(accounts.length, 1);
      expect(accounts.first.balance, 150);
    });

    test('updateHistoryRecord rejects edit that would cause negative balance',
        () async {
      final createResult = await repository.createAccount(
        name: 'Test Account Negative',
        openingBalance: 50,
      );
      expect(createResult.success, isTrue);

      final accountId = (await repository.getAllAccounts()).first.id;
      final removeResult = await repository.removeMoney(
        accountId: accountId,
        amount: 25,
        note: 'Withdrawal',
      );
      expect(removeResult.success, isTrue);

      final history = await repository.getAllHistory();
      final removeRecord = history.firstWhere(
        (r) => r.action == MoneyHistoryAction.moneyRemoved,
      );

      final updateResult = await repository.updateHistoryRecord(
        recordId: removeRecord.id,
        amount: 100,
      );
      expect(updateResult.success, isFalse);
      expect(
        updateResult.message,
        contains('invalid state'),
      );

      final accounts = await repository.getAllAccounts();
      expect(accounts.first.balance, 25);
    });

    test('updateHistoryRecord updates amount and replays balance correctly',
        () async {
      final createResult = await repository.createAccount(
        name: 'Test Account Amount',
        openingBalance: 100,
      );
      expect(createResult.success, isTrue);

      final accountId = (await repository.getAllAccounts()).first.id;
      await repository.addMoney(
        accountId: accountId,
        amount: 50,
        note: 'Deposit',
      );

      final history = await repository.getAllHistory();
      final addRecord = history.firstWhere(
        (r) => r.action == MoneyHistoryAction.moneyAdded,
      );

      final updateResult = await repository.updateHistoryRecord(
        recordId: addRecord.id,
        amount: 30,
      );
      expect(updateResult.success, isTrue);

      final accounts = await repository.getAllAccounts();
      expect(accounts.first.balance, 130);
    });
  });
}
