import 'package:shared_preferences/shared_preferences.dart';

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
