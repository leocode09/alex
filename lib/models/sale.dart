class Sale {
  final String id;
  final List<SaleItem> items;
  final double total;
  final DateTime timestamp;
  final String paymentMethod;

  Sale({
    required this.id,
    required this.items,
    required this.total,
    required this.timestamp,
    this.paymentMethod = 'Cash',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'timestamp': timestamp.toIso8601String(),
      'paymentMethod': paymentMethod,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as String,
      items: (map['items'] as List)
          .map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      total: (map['total'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      paymentMethod: map['paymentMethod'] as String? ?? 'Cash',
    );
  }
}

class SaleItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
  });

  double get subtotal => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
    );
  }
}
