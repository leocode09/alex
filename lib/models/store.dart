class Store {
  final String id;
  final String name;
  final String location;
  final String address;
  final String? phone;
  final String? managerId;
  final bool isActive;
  final DateTime createdAt;

  Store({
    required this.id,
    required this.name,
    required this.location,
    required this.address,
    this.phone,
    this.managerId,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'address': address,
      'phone': phone,
      'managerId': managerId,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'] as String,
      name: map['name'] as String,
      location: map['location'] as String,
      address: map['address'] as String,
      phone: map['phone'] as String?,
      managerId: map['managerId'] as String?,
      isActive: (map['isActive'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Store copyWith({
    String? id,
    String? name,
    String? location,
    String? address,
    String? phone,
    String? managerId,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      managerId: managerId ?? this.managerId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
