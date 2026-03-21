/// Picker-only sentinel: single-item line uses [Product.price], not package math.
const String productPackageSingleItemId = '__single__';

/// Selling price for one cart line of [pkg] given the product's per-unit price.
double sellingPriceForPackage({
  required double unitPrice,
  required ProductPackage pkg,
}) {
  if (pkg.id == productPackageSingleItemId) return unitPrice;
  return pkg.packagePrice ?? (unitPrice * pkg.unitsPerPackage);
}

/// A sellable package preset for a product (e.g. 1 item, 1/4 pack, 1/2 pack, full pack).
/// When [packagePrice] is null, selling price is [Product.price] × [unitsPerPackage].
class ProductPackage {
  final String id;
  final String name;
  final int unitsPerPackage;
  final double? packagePrice;

  ProductPackage({
    required this.id,
    required this.name,
    required this.unitsPerPackage,
    this.packagePrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unitsPerPackage': unitsPerPackage,
      if (packagePrice != null) 'packagePrice': packagePrice,
    };
  }

  factory ProductPackage.fromMap(Map<String, dynamic> map) {
    return ProductPackage(
      id: map['id'] as String,
      name: map['name'] as String,
      unitsPerPackage: (map['unitsPerPackage'] as num).toInt(),
      packagePrice: map['packagePrice'] != null
          ? (map['packagePrice'] as num).toDouble()
          : null,
    );
  }

  ProductPackage copyWith({
    String? id,
    String? name,
    int? unitsPerPackage,
    double? packagePrice,
  }) {
    return ProductPackage(
      id: id ?? this.id,
      name: name ?? this.name,
      unitsPerPackage: unitsPerPackage ?? this.unitsPerPackage,
      packagePrice: packagePrice ?? this.packagePrice,
    );
  }
}

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
  final List<ProductPackage> packages;
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
    List<ProductPackage>? packages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : packages = packages ?? [],
        createdAt = createdAt ?? DateTime.now(),
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
      'packages': packages.map((p) => p.toMap()).toList(),
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
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      barcode: map['barcode'] as String?,
      sku: map['sku'] as String?,
      description: map['description'] as String?,
      category: map['category'] as String?,
      supplier: map['supplier'] as String?,
      packages: (map['packages'] as List<dynamic>?)
              ?.map((e) => ProductPackage.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
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
    String? sku,
    String? description,
    String? category,
    String? supplier,
    List<ProductPackage>? packages,
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
      sku: sku ?? this.sku,
      description: description ?? this.description,
      category: category ?? this.category,
      supplier: supplier ?? this.supplier,
      packages: packages ?? this.packages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
