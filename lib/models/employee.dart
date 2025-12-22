class Employee {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final bool isActive;
  final DateTime joinDate;
  final int salesCount;
  final double totalSales;

  Employee({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.isActive = true,
    DateTime? joinDate,
    this.salesCount = 0,
    this.totalSales = 0.0,
  }) : joinDate = joinDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'isActive': isActive ? 1 : 0,
      'joinDate': joinDate.toIso8601String(),
      'salesCount': salesCount,
      'totalSales': totalSales,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String?,
      role: map['role'] as String,
      isActive: (map['isActive'] as int) == 1,
      joinDate: DateTime.parse(map['joinDate'] as String),
      salesCount: map['salesCount'] as int? ?? 0,
      totalSales: (map['totalSales'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Employee copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
    DateTime? joinDate,
    int? salesCount,
    double? totalSales,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      joinDate: joinDate ?? this.joinDate,
      salesCount: salesCount ?? this.salesCount,
      totalSales: totalSales ?? this.totalSales,
    );
  }
}
