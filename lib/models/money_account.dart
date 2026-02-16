class MoneyAccount {
  final String id;
  final String name;
  final double balance;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  MoneyAccount({
    required this.id,
    required this.name,
    required this.balance,
    this.note,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MoneyAccount.fromMap(Map<String, dynamic> map) {
    return MoneyAccount(
      id: map['id'] as String,
      name: (map['name'] ?? 'Account') as String,
      balance: (map['balance'] as num? ?? 0).toDouble(),
      note: map['note'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : (map['createdAt'] != null
              ? DateTime.parse(map['createdAt'] as String)
              : DateTime.now()),
    );
  }

  MoneyAccount copyWith({
    String? id,
    String? name,
    double? balance,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MoneyAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
