import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReceiptPrintService {
  static const String _receiptPrintCountsKey = 'receipt_print_counts';

  Future<int> getPrintCount(String saleId) async {
    final counts = await _loadPrintCounts();
    return counts[saleId] ?? 0;
  }

  Future<int> getNextPrintNumber(String saleId) async {
    final currentCount = await getPrintCount(saleId);
    return currentCount + 1;
  }

  Future<void> markPrinted(String saleId, {required int printNumber}) async {
    final counts = await _loadPrintCounts();
    final currentCount = counts[saleId] ?? 0;
    if (printNumber > currentCount) {
      counts[saleId] = printNumber;
      await _savePrintCounts(counts);
    }
  }

  String buildPrintLabel(int printNumber) {
    if (printNumber <= 1) {
      return 'Original Print';
    }
    return 'Reprint #$printNumber';
  }

  Future<Map<String, int>> _loadPrintCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_receiptPrintCountsKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return {};
      }

      final parsed = <String, int>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is num) {
          parsed[entry.key] = value.toInt();
        }
      }
      return parsed;
    } catch (_) {
      return {};
    }
  }

  Future<void> _savePrintCounts(Map<String, int> counts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_receiptPrintCountsKey, jsonEncode(counts));
  }
}
