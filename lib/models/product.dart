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

/// Base units represented by [packages] using each line's [ProductPackage.packageCount].
int baseUnitsInPackages(List<ProductPackage> packages) {
  var sum = 0;
  for (final p in packages) {
    sum += p.packageCount * p.unitsPerPackage;
  }
  return sum;
}

/// Total sellable base units: loose singles plus units held in named packages.
int totalBaseUnitsStock(Product product) {
  return product.looseStock + baseUnitsInPackages(product.packages);
}

/// A sellable package preset for a product (e.g. 1 item, 1/4 pack, 1/2 pack, full pack).
/// When [packagePrice] is null, selling price is [Product.price] × [unitsPerPackage].
/// [packageCount] is how many of this package are in stock (inventory in package units).
class ProductPackage {
  final String id;
  final String name;
  final int unitsPerPackage;
  final double? packagePrice;
  final int packageCount;

  ProductPackage({
    required this.id,
    required this.name,
    required this.unitsPerPackage,
    this.packagePrice,
    this.packageCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unitsPerPackage': unitsPerPackage,
      if (packagePrice != null) 'packagePrice': packagePrice,
      'packageCount': packageCount,
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
      packageCount: (map['packageCount'] as num?)?.toInt() ?? 0,
    );
  }

  ProductPackage copyWith({
    String? id,
    String? name,
    int? unitsPerPackage,
    double? packagePrice,
    int? packageCount,
  }) {
    return ProductPackage(
      id: id ?? this.id,
      name: name ?? this.name,
      unitsPerPackage: unitsPerPackage ?? this.unitsPerPackage,
      packagePrice: packagePrice ?? this.packagePrice,
      packageCount: packageCount ?? this.packageCount,
    );
  }
}

class Product {
  final String id;
  final String name;
  final double price;
  final double? costPrice;
  final int stock;
  /// Base units not attributed to a named package line (singles / unallocated).
  final int looseStock;
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
    this.looseStock = 0,
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
      'looseStock': looseStock,
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
    final packages = (map['packages'] as List<dynamic>?)
            ?.map((e) => ProductPackage.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    final stock = (map['stock'] as num?)?.toInt() ?? 0;
    int looseStock;
    if (map['looseStock'] != null) {
      looseStock = (map['looseStock'] as num).toInt();
    } else {
      final inPackages = baseUnitsInPackages(packages);
      looseStock = inPackages > 0 ? (stock - inPackages).clamp(0, stock) : stock;
    }
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      costPrice: map['costPrice'] != null
          ? (map['costPrice'] as num).toDouble()
          : null,
      stock: stock,
      looseStock: looseStock,
      barcode: map['barcode'] as String?,
      sku: map['sku'] as String?,
      description: map['description'] as String?,
      category: map['category'] as String?,
      supplier: map['supplier'] as String?,
      packages: packages,
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
    int? looseStock,
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
      looseStock: looseStock ?? this.looseStock,
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
