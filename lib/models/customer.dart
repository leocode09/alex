class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final int totalPurchases;
  final double totalSpent;
  final DateTime joinDate;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.totalPurchases = 0,
    this.totalSpent = 0.0,
    DateTime? joinDate,
    DateTime? updatedAt,
  })  : joinDate = joinDate ?? DateTime.now(),
        updatedAt = updatedAt ?? joinDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'totalPurchases': totalPurchases,
      'totalSpent': totalSpent,
      'joinDate': joinDate.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    final joinDate = DateTime.parse(map['joinDate'] as String);
    final rawUpdatedAt = map['updatedAt'];
    final updatedAt = rawUpdatedAt is String
        ? DateTime.tryParse(rawUpdatedAt) ?? joinDate
        : joinDate;
    return Customer(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      totalPurchases: map['totalPurchases'] as int? ?? 0,
      totalSpent: (map['totalSpent'] as num?)?.toDouble() ?? 0.0,
      joinDate: joinDate,
      updatedAt: updatedAt,
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    int? totalPurchases,
    double? totalSpent,
    DateTime? joinDate,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalSpent: totalSpent ?? this.totalSpent,
      joinDate: joinDate ?? this.joinDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
