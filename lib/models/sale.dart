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
  final double amountPaid;
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
    double? amountPaid,
    DateTime? createdAt,
  })  : amountPaid = amountPaid ?? total,
        createdAt = createdAt ?? DateTime.now();

  /// How much of the sale total is still owed by the customer. Always
  /// non-negative (overpayments don't surface here).
  double get amountDue {
    final due = total - amountPaid;
    return due > 0 ? due : 0;
  }

  /// True when the customer has fully paid for this sale.
  bool get isPaidInFull => amountDue <= 0.000001;

  /// Number of distinct products on this sale (deduplicated by `productId`).
  /// Two line items for the same product sold in different packages count as
  /// one product, while `items.length` counts every line separately.
  int get totalProducts =>
      items.map((item) => item.productId).toSet().length;

  static const Object _keep = Object();

  Sale copyWith({
    String? id,
    List<SaleItem>? items,
    double? total,
    String? paymentMethod,
    Object? customerId = _keep,
    Object? customerNameSnapshot = _keep,
    String? employeeId,
    Object? cashReceived = _keep,
    Object? change = _keep,
    double? creditApplied,
    double? bonusEarned,
    double? customerTotalSpentAfter,
    double? customerCreditBalanceAfter,
    double? amountPaid,
    DateTime? createdAt,
  }) {
    return Sale(
      id: id ?? this.id,
      items: items ?? this.items,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: identical(customerId, _keep)
          ? this.customerId
          : customerId as String?,
      customerNameSnapshot: identical(customerNameSnapshot, _keep)
          ? this.customerNameSnapshot
          : customerNameSnapshot as String?,
      employeeId: employeeId ?? this.employeeId,
      cashReceived: identical(cashReceived, _keep)
          ? this.cashReceived
          : cashReceived as double?,
      change: identical(change, _keep) ? this.change : change as double?,
      creditApplied: creditApplied ?? this.creditApplied,
      bonusEarned: bonusEarned ?? this.bonusEarned,
      customerTotalSpentAfter:
          customerTotalSpentAfter ?? this.customerTotalSpentAfter,
      customerCreditBalanceAfter:
          customerCreditBalanceAfter ?? this.customerCreditBalanceAfter,
      amountPaid: amountPaid ?? this.amountPaid,
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
      'amountPaid': amountPaid,
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
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ??
          (map['total'] as num).toDouble(),
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
