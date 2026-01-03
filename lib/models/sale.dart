class Sale {
  final String id;
  final List<SaleItem> items;
  final double total;
  final String paymentMethod;
  final String? customerId;
  final String employeeId;
  final DateTime createdAt;

  Sale({
    required this.id,
    required this.items,
    required this.total,
    required this.paymentMethod,
    this.customerId,
    required this.employeeId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'paymentMethod': paymentMethod,
      'customerId': customerId,
      'employeeId': employeeId,
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
      employeeId: map['employeeId'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class SaleItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final double subtotal;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  }) : subtotal = quantity * price;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      quantity: map['quantity'] as int,
      price: (map['price'] as num).toDouble(),
    );
  }
}
