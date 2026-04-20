enum CustomerCreditEntryType {
  bonus,
  redeem,
  manualAdjustment,
}

CustomerCreditEntryType _parseType(String? raw) {
  switch (raw) {
    case 'bonus':
      return CustomerCreditEntryType.bonus;
    case 'redeem':
      return CustomerCreditEntryType.redeem;
    case 'manualAdjustment':
      return CustomerCreditEntryType.manualAdjustment;
    default:
      return CustomerCreditEntryType.manualAdjustment;
  }
}

String _typeToString(CustomerCreditEntryType type) {
  switch (type) {
    case CustomerCreditEntryType.bonus:
      return 'bonus';
    case CustomerCreditEntryType.redeem:
      return 'redeem';
    case CustomerCreditEntryType.manualAdjustment:
      return 'manualAdjustment';
  }
}

/// Ledger entry for customer credit. Positive [amount] credits the customer
/// (bonus / manual top-up); negative [amount] debits the customer (redemption
/// at checkout / manual deduction).
class CustomerCreditEntry {
  final String id;
  final String customerId;
  final CustomerCreditEntryType type;
  final double amount;
  final String? saleId;
  final String? reason;
  final DateTime createdAt;

  CustomerCreditEntry({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    this.saleId,
    this.reason,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  CustomerCreditEntry copyWith({
    String? id,
    String? customerId,
    CustomerCreditEntryType? type,
    double? amount,
    String? saleId,
    String? reason,
    DateTime? createdAt,
  }) {
    return CustomerCreditEntry(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      saleId: saleId ?? this.saleId,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'type': _typeToString(type),
      'amount': amount,
      'saleId': saleId,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomerCreditEntry.fromMap(Map<String, dynamic> map) {
    return CustomerCreditEntry(
      id: map['id'] as String,
      customerId: map['customerId'] as String,
      type: _parseType(map['type'] as String?),
      amount: (map['amount'] as num).toDouble(),
      saleId: map['saleId'] as String?,
      reason: map['reason'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
