enum MoneyHistoryAction {
  accountCreated,
  accountUpdated,
  accountDeleted,
  moneyAdded,
  moneyRemoved,
}

extension MoneyHistoryActionX on MoneyHistoryAction {
  String get value {
    switch (this) {
      case MoneyHistoryAction.accountCreated:
        return 'account_created';
      case MoneyHistoryAction.accountUpdated:
        return 'account_updated';
      case MoneyHistoryAction.accountDeleted:
        return 'account_deleted';
      case MoneyHistoryAction.moneyAdded:
        return 'money_added';
      case MoneyHistoryAction.moneyRemoved:
        return 'money_removed';
    }
  }

  static MoneyHistoryAction fromValue(String? value) {
    switch (value) {
      case 'account_created':
        return MoneyHistoryAction.accountCreated;
      case 'account_updated':
        return MoneyHistoryAction.accountUpdated;
      case 'account_deleted':
        return MoneyHistoryAction.accountDeleted;
      case 'money_added':
        return MoneyHistoryAction.moneyAdded;
      case 'money_removed':
        return MoneyHistoryAction.moneyRemoved;
      default:
        return MoneyHistoryAction.accountUpdated;
    }
  }
}

class AccountHistoryRecord {
  final String id;
  final String accountId;
  final String accountName;
  final MoneyHistoryAction action;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? note;
  final DateTime createdAt;

  AccountHistoryRecord({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.action,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCredit =>
      action == MoneyHistoryAction.moneyAdded ||
      (action == MoneyHistoryAction.accountCreated && amount > 0);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accountId': accountId,
      'accountName': accountName,
      'action': action.value,
      'amount': amount,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AccountHistoryRecord.fromMap(Map<String, dynamic> map) {
    return AccountHistoryRecord(
      id: map['id'] as String,
      accountId: (map['accountId'] ?? '') as String,
      accountName: (map['accountName'] ?? 'Account') as String,
      action: MoneyHistoryActionX.fromValue(map['action'] as String?),
      amount: (map['amount'] as num? ?? 0).toDouble(),
      balanceBefore: (map['balanceBefore'] as num? ?? 0).toDouble(),
      balanceAfter: (map['balanceAfter'] as num? ?? 0).toDouble(),
      note: map['note'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
