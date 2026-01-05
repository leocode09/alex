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
  final double? discountPercentage; // Discount as percentage (0-100)
  final double? discountAmount; // Fixed discount amount
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
    this.discountPercentage,
    this.discountAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Calculate the final price after applying discount
  double get finalPrice {
    double discountedPrice = price;
    
    // Apply percentage discount first
    if (discountPercentage != null && discountPercentage! > 0) {
      discountedPrice = price * (1 - discountPercentage! / 100);
    }
    
    // Then apply fixed amount discount
    if (discountAmount != null && discountAmount! > 0) {
      discountedPrice = discountedPrice - discountAmount!;
    }
    
    // Ensure price doesn't go below 0
    return discountedPrice < 0 ? 0 : discountedPrice;
  }

  /// Check if product has any active discount
  bool get hasDiscount {
    return (discountPercentage != null && discountPercentage! > 0) ||
           (discountAmount != null && discountAmount! > 0);
  }

  /// Get total discount amount
  double get totalDiscount {
    return price - finalPrice;
  }

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
      'discountPercentage': discountPercentage,
      'discountAmount': discountAmount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      costPrice: map['costPrice'] != null ? (map['costPrice'] as num).toDouble() : null,
      stock: map['stock'] as int,
      barcode: map['barcode'] as String?,
      sku: map['sku'] as String?,
      description: map['description'] as String?,
      category: map['category'] as String?,
      supplier: map['supplier'] as String?,
      discountPercentage: map['discountPercentage'] != null ? (map['discountPercentage'] as num).toDouble() : null,
      discountAmount: map['discountAmount'] != null ? (map['discountAmount'] as num).toDouble() : null,
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
    double? discountPercentage,
    double? discountAmount,
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
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountAmount: discountAmount ?? this.discountAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
