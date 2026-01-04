import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaxSettings {
  final double taxRate;
  final bool includeTax;

  TaxSettings({
    this.taxRate = 0.18, // 18% VAT (Rwanda standard rate)
    this.includeTax = true,
  });

  TaxSettings copyWith({
    double? taxRate,
    bool? includeTax,
  }) {
    return TaxSettings(
      taxRate: taxRate ?? this.taxRate,
      includeTax: includeTax ?? this.includeTax,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taxRate': taxRate,
      'includeTax': includeTax,
    };
  }

  factory TaxSettings.fromMap(Map<String, dynamic> map) {
    return TaxSettings(
      taxRate: map['taxRate'] ?? 0.18,
      includeTax: map['includeTax'] ?? true,
    );
  }
}

class TaxSettingsNotifier extends StateNotifier<TaxSettings> {
  TaxSettingsNotifier() : super(TaxSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('tax_settings');
    if (settingsJson != null) {
      final map = jsonDecode(settingsJson) as Map<String, dynamic>;
      state = TaxSettings.fromMap(map);
    }
  }

  Future<void> updateSettings(TaxSettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tax_settings', jsonEncode(settings.toMap()));
  }

  Future<void> updateTaxRate(double rate) async {
    await updateSettings(state.copyWith(taxRate: rate));
  }

  Future<void> updateIncludeTax(bool include) async {
    await updateSettings(state.copyWith(includeTax: include));
  }
}

final taxSettingsProvider =
    StateNotifierProvider<TaxSettingsNotifier, TaxSettings>((ref) {
  return TaxSettingsNotifier();
});
