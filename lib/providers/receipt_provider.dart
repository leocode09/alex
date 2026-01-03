import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptSettings {
  final String shopName;
  final String addressLine1;
  final String addressLine2;
  final String phone;
  final String footerMessage;

  ReceiptSettings({
    this.shopName = 'Alex Shop',
    this.addressLine1 = 'Mbare musika',
    this.addressLine2 = 'Harare',
    this.phone = '0784712870',
    this.footerMessage = 'Thank You',
  });

  ReceiptSettings copyWith({
    String? shopName,
    String? addressLine1,
    String? addressLine2,
    String? phone,
    String? footerMessage,
  }) {
    return ReceiptSettings(
      shopName: shopName ?? this.shopName,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      phone: phone ?? this.phone,
      footerMessage: footerMessage ?? this.footerMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopName': shopName,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'phone': phone,
      'footerMessage': footerMessage,
    };
  }

  factory ReceiptSettings.fromMap(Map<String, dynamic> map) {
    return ReceiptSettings(
      shopName: map['shopName'] ?? 'Alex Shop',
      addressLine1: map['addressLine1'] ?? 'Mbare musika',
      addressLine2: map['addressLine2'] ?? 'Harare',
      phone: map['phone'] ?? '0784712870',
      footerMessage: map['footerMessage'] ?? 'Thank You',
    );
  }
}

class ReceiptSettingsNotifier extends StateNotifier<ReceiptSettings> {
  ReceiptSettingsNotifier() : super(ReceiptSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('receipt_settings');
    if (settingsJson != null) {
      state = ReceiptSettings.fromMap(jsonDecode(settingsJson));
    }
  }

  Future<void> updateSettings(ReceiptSettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('receipt_settings', jsonEncode(settings.toMap()));
  }
}

final receiptSettingsProvider = StateNotifierProvider<ReceiptSettingsNotifier, ReceiptSettings>((ref) {
  return ReceiptSettingsNotifier();
});
