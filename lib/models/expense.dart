class Expense {
  final String id;
  final String title;
  final double amount;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    this.note,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    final createdAt =
        _parseDateTime(map['createdAt']) ?? _parseDateTime(map['date']) ?? DateTime.now();
    final updatedAt = _parseDateTime(map['updatedAt']) ??
        _parseDateTime(map['modifiedAt']) ??
        createdAt;

    return Expense(
      id: map['id'] as String,
      title: (map['title'] ?? map['name'] ?? 'Expense') as String,
      amount: _parseAmount(map['amount']),
      note: map['note'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static double _parseAmount(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '');
      return double.tryParse(normalized) ?? 0.0;
    }
    return 0.0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) {
        return null;
      }
      return DateTime.tryParse(text);
    }
    if (value is int) {
      if (value <= 0) {
        return null;
      }
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    return null;
  }

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
