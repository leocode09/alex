class InventoryMovement {
  static const String varianceReasonPrefix = 'variance_';

  final String id;
  final String productId;
  final String productName;
  final int delta;
  final int stockBefore;
  final int stockAfter;
  final String reason;
  final String? referenceId;
  final String? note;
  final double? unitPrice;
  final double? unitCost;
  final DateTime createdAt;

  InventoryMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.delta,
    required this.stockBefore,
    required this.stockAfter,
    required this.reason,
    this.referenceId,
    this.note,
    this.unitPrice,
    this.unitCost,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isStockIn => delta > 0;
  bool get isStockOut => delta < 0;
  bool get isVariance => reason.startsWith(varianceReasonPrefix);
  bool get isVarianceMatch => isVariance && delta == 0;
  String? get varianceCode =>
      isVariance ? reason.substring(varianceReasonPrefix.length) : null;
  double get retailValueImpact => (unitPrice ?? 0) * delta;
  double get costValueImpact => (unitCost ?? 0) * delta;

  static bool isVarianceReason(String reason) =>
      reason.startsWith(varianceReasonPrefix);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'delta': delta,
      'stockBefore': stockBefore,
      'stockAfter': stockAfter,
      'reason': reason,
      'referenceId': referenceId,
      'note': note,
      'unitPrice': unitPrice,
      'unitCost': unitCost,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory InventoryMovement.fromMap(Map<String, dynamic> map) {
    return InventoryMovement(
      id: map['id'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String? ?? '',
      delta: (map['delta'] as num?)?.toInt() ?? 0,
      stockBefore: (map['stockBefore'] as num?)?.toInt() ?? 0,
      stockAfter: (map['stockAfter'] as num?)?.toInt() ?? 0,
      reason: map['reason'] as String? ?? 'stock_adjustment',
      referenceId: map['referenceId'] as String?,
      note: map['note'] as String?,
      unitPrice: (map['unitPrice'] as num?)?.toDouble(),
      unitCost: (map['unitCost'] as num?)?.toDouble(),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
