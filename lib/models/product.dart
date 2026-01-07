class Product {
  final String id;
  final String name;
  final double price;
  final double? costPrice;
  final int stock;
  final String? barcode;
  final String? sku;
  final String? description;
  final String? category;
  final String? supplier;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.costPrice,
    required this.stock,
    this.barcode,
    this.sku,
    this.description,
    this.category,
    this.supplier,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'costPrice': costPrice,
      'stock': stock,
      'barcode': barcode,
      'sku': sku,
      'description': description,
      'category': category,
      'supplier': supplier,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      costPrice: map['costPrice'] != null
          ? (map['costPrice'] as num).toDouble()
          : null,
      stock: map['stock'] as int,
      barcode: map['barcode'] as String?,
      sku: map['sku'] as String?,
      description: map['description'] as String?,
      category: map['category'] as String?,
      supplier: map['supplier'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Product copyWith({
    String? id,
    String? name,
    double? price,
    double? costPrice,
    int? stock,
    String? barcode,
    String? category,
    String? supplier,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      supplier: supplier ?? this.supplier,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
