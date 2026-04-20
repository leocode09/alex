class Sale {
  final String id;
  final List<SaleItem> items;
  final double total;
  final String paymentMethod;
  final String? customerId;
  final String? customerNameSnapshot;
  final String employeeId;
  final double? cashReceived;
  final double? change;
  final double creditApplied;
  final double bonusEarned;
  final double customerTotalSpentAfter;
  final double customerCreditBalanceAfter;
  final DateTime createdAt;

  Sale({
    required this.id,
    required this.items,
    required this.total,
    required this.paymentMethod,
    this.customerId,
    this.customerNameSnapshot,
    required this.employeeId,
    this.cashReceived,
    this.change,
    this.creditApplied = 0.0,
    this.bonusEarned = 0.0,
    this.customerTotalSpentAfter = 0.0,
    this.customerCreditBalanceAfter = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Sale copyWith({
    String? id,
    List<SaleItem>? items,
    double? total,
    String? paymentMethod,
    String? customerId,
    String? customerNameSnapshot,
    String? employeeId,
    double? cashReceived,
    double? change,
    double? creditApplied,
    double? bonusEarned,
    double? customerTotalSpentAfter,
    double? customerCreditBalanceAfter,
    DateTime? createdAt,
  }) {
    return Sale(
      id: id ?? this.id,
      items: items ?? this.items,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: customerId ?? this.customerId,
      customerNameSnapshot: customerNameSnapshot ?? this.customerNameSnapshot,
      employeeId: employeeId ?? this.employeeId,
      cashReceived: cashReceived ?? this.cashReceived,
      change: change ?? this.change,
      creditApplied: creditApplied ?? this.creditApplied,
      bonusEarned: bonusEarned ?? this.bonusEarned,
      customerTotalSpentAfter:
          customerTotalSpentAfter ?? this.customerTotalSpentAfter,
      customerCreditBalanceAfter:
          customerCreditBalanceAfter ?? this.customerCreditBalanceAfter,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'paymentMethod': paymentMethod,
      'customerId': customerId,
      'customerNameSnapshot': customerNameSnapshot,
      'employeeId': employeeId,
      'cashReceived': cashReceived,
      'change': change,
      'creditApplied': creditApplied,
      'bonusEarned': bonusEarned,
      'customerTotalSpentAfter': customerTotalSpentAfter,
      'customerCreditBalanceAfter': customerCreditBalanceAfter,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as String,
      items: (map['items'] as List)
          .map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      total: (map['total'] as num).toDouble(),
      paymentMethod: map['paymentMethod'] as String,
      customerId: map['customerId'] as String?,
      customerNameSnapshot: map['customerNameSnapshot'] as String?,
      employeeId: map['employeeId'] as String,
      cashReceived: map['cashReceived'] != null
          ? (map['cashReceived'] as num).toDouble()
          : null,
      change: map['change'] != null ? (map['change'] as num).toDouble() : null,
      creditApplied: (map['creditApplied'] as num?)?.toDouble() ?? 0.0,
      bonusEarned: (map['bonusEarned'] as num?)?.toDouble() ?? 0.0,
      customerTotalSpentAfter:
          (map['customerTotalSpentAfter'] as num?)?.toDouble() ?? 0.0,
      customerCreditBalanceAfter:
          (map['customerCreditBalanceAfter'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class SaleItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price; // Price per unit or per package (for display)
  final double? discount; // Discount amount per item
  final double subtotal;
  final String? packageId;
  final String? packageName;
  final int? unitsPerPackage;
  final double? costPrice; // Per base-unit cost at time of sale

  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.discount,
    this.packageId,
    this.packageName,
    this.unitsPerPackage,
    this.costPrice,
  }) : subtotal = quantity * (price - (discount ?? 0));

  /// Base units consumed for stock deduction. When sold by package: quantity * unitsPerPackage; otherwise quantity.
  int get baseUnitsSold =>
      unitsPerPackage != null ? quantity * unitsPerPackage! : quantity;

  /// Profit for this line item (null when costPrice is unknown).
  double? get profit =>
      costPrice != null ? subtotal - costPrice! * baseUnitsSold : null;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'discount': discount,
      'packageId': packageId,
      'packageName': packageName,
      'unitsPerPackage': unitsPerPackage,
      'costPrice': costPrice,
      'subtotal': subtotal,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      quantity: (map['quantity'] as num).toInt(),
      price: (map['price'] as num).toDouble(),
      discount:
          map['discount'] != null ? (map['discount'] as num).toDouble() : null,
      packageId: map['packageId'] as String?,
      packageName: map['packageName'] as String?,
      unitsPerPackage: map['unitsPerPackage'] != null
          ? (map['unitsPerPackage'] as num).toInt()
          : null,
      costPrice: map['costPrice'] != null
          ? (map['costPrice'] as num).toDouble()
          : null,
    );
  }
}
