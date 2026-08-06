import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Collections with more entries than this are encoded off the UI thread.
const int _encodeComputeThreshold = 300;

/// Raw JSON strings longer than this are encoded/decoded off the UI thread.
const int _jsonComputeCharThreshold = 100000;

/// Encodes [value] to JSON, offloading to a background isolate via [compute]
/// when the payload is large. [value] must be JSON-safe (maps/lists/strings/
/// nums/bools/null) so it can cross the isolate boundary.
Future<String> encodeJson(Object? value) async {
  final bool isLarge =
      (value is List && value.length > _encodeComputeThreshold) ||
          (value is String && value.length > _jsonComputeCharThreshold);
  if (isLarge) {
    return compute(jsonEncode, value);
  }
  return jsonEncode(value);
}

/// Decodes [raw] JSON, offloading to a background isolate via [compute] when
/// the string is large.
Future<dynamic> decodeJson(String raw) async {
  if (raw.length > _jsonComputeCharThreshold) {
    return compute(jsonDecode, raw);
  }
  return jsonDecode(raw);
}

/// Simple storage helper using SharedPreferences
class StorageHelper {
  static final StorageHelper _instance = StorageHelper._internal();
  static SharedPreferences? _prefs;

  factory StorageHelper() {
    return _instance;
  }

  StorageHelper._internal();

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    print('✓ Storage initialized');
    return _prefs!;
  }

  // Save data as JSON string
  Future<bool> saveData(String key, String jsonData) async {
    final storage = await prefs;
    return await storage.setString(key, jsonData);
  }

  // Get data as JSON string
  Future<String?> getData(String key) async {
    final storage = await prefs;
    return storage.getString(key);
  }

  // Delete data
  Future<bool> deleteData(String key) async {
    final storage = await prefs;
    return await storage.remove(key);
  }

  // Clear all data
  Future<bool> clearAll() async {
    final storage = await prefs;
    return await storage.clear();
  }

  // Check if key exists
  Future<bool> hasData(String key) async {
    final storage = await prefs;
    return storage.containsKey(key);
  }
}
