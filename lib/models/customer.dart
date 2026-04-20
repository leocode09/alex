class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final int totalPurchases;
  final double totalSpent;
  final double creditBalance;
  final double totalBonusEarned;
  final double totalCreditRedeemed;
  final DateTime joinDate;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.totalPurchases = 0,
    this.totalSpent = 0.0,
    this.creditBalance = 0.0,
    this.totalBonusEarned = 0.0,
    this.totalCreditRedeemed = 0.0,
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
      'address': address,
      'notes': notes,
      'totalPurchases': totalPurchases,
      'totalSpent': totalSpent,
      'creditBalance': creditBalance,
      'totalBonusEarned': totalBonusEarned,
      'totalCreditRedeemed': totalCreditRedeemed,
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
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      totalPurchases: map['totalPurchases'] as int? ?? 0,
      totalSpent: (map['totalSpent'] as num?)?.toDouble() ?? 0.0,
      creditBalance: (map['creditBalance'] as num?)?.toDouble() ?? 0.0,
      totalBonusEarned: (map['totalBonusEarned'] as num?)?.toDouble() ?? 0.0,
      totalCreditRedeemed:
          (map['totalCreditRedeemed'] as num?)?.toDouble() ?? 0.0,
      joinDate: joinDate,
      updatedAt: updatedAt,
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    int? totalPurchases,
    double? totalSpent,
    double? creditBalance,
    double? totalBonusEarned,
    double? totalCreditRedeemed,
    DateTime? joinDate,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalSpent: totalSpent ?? this.totalSpent,
      creditBalance: creditBalance ?? this.creditBalance,
      totalBonusEarned: totalBonusEarned ?? this.totalBonusEarned,
      totalCreditRedeemed: totalCreditRedeemed ?? this.totalCreditRedeemed,
      joinDate: joinDate ?? this.joinDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
