/// Shop-wide settings synced across devices (receipt header, tax, bonus).
class ShopAppSettings {
  final Map<String, dynamic>? receipt;
  final Map<String, dynamic>? tax;
  final Map<String, dynamic>? bonus;
  final DateTime updatedAt;

  const ShopAppSettings({
    this.receipt,
    this.tax,
    this.bonus,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        if (receipt != null) 'receipt': receipt,
        if (tax != null) 'tax': tax,
        if (bonus != null) 'bonus': bonus,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ShopAppSettings.fromJson(Map<String, dynamic> json) {
    return ShopAppSettings(
      receipt: json['receipt'] is Map
          ? Map<String, dynamic>.from(json['receipt'] as Map)
          : null,
      tax: json['tax'] is Map
          ? Map<String, dynamic>.from(json['tax'] as Map)
          : null,
      bonus: json['bonus'] is Map
          ? Map<String, dynamic>.from(json['bonus'] as Map)
          : null,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool get isEmpty => receipt == null && tax == null && bonus == null;
}
