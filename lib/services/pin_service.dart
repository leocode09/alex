import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const String _pinKey = 'user_pin';
  static const String _pinSetKey = 'pin_is_set';
  static const String _pinOnLoginKey = 'pin_on_login';
  static const String _pinOnAddProductKey = 'pin_on_add_product';
  static const String _pinOnEditProductKey = 'pin_on_edit_product';
  static const String _pinOnDeleteProductKey = 'pin_on_delete_product';
  static const String _pinOnSettingsKey = 'pin_on_settings';
  static const String _pinOnReportsKey = 'pin_on_reports';

  Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinSetKey) ?? false;
  }

  Future<void> setPin(String pin, {
    bool requireOnLogin = true,
    bool requireOnAddProduct = false,
    bool requireOnEditProduct = false,
    bool requireOnDeleteProduct = false,
    bool requireOnSettings = false,
    bool requireOnReports = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    await prefs.setBool(_pinSetKey, true);
    await prefs.setBool(_pinOnLoginKey, requireOnLogin);
    await prefs.setBool(_pinOnAddProductKey, requireOnAddProduct);
    await prefs.setBool(_pinOnEditProductKey, requireOnEditProduct);
    await prefs.setBool(_pinOnDeleteProductKey, requireOnDeleteProduct);
    await prefs.setBool(_pinOnSettingsKey, requireOnSettings);
    await prefs.setBool(_pinOnReportsKey, requireOnReports);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_pinKey);
    return storedPin == pin;
  }

  Future<bool> isPinRequiredForLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnLoginKey) ?? true;
  }

  Future<bool> isPinRequiredForAddProduct() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnAddProductKey) ?? false;
  }

  Future<bool> isPinRequiredForEditProduct() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnEditProductKey) ?? false;
  }

  Future<bool> isPinRequiredForDeleteProduct() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnDeleteProductKey) ?? false;
  }

  Future<bool> isPinRequiredForSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnSettingsKey) ?? false;
  }

  Future<bool> isPinRequiredForReports() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinOnReportsKey) ?? false;
  }

  Future<Map<String, bool>> getPinPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'login': prefs.getBool(_pinOnLoginKey) ?? true,
      'addProduct': prefs.getBool(_pinOnAddProductKey) ?? false,
      'editProduct': prefs.getBool(_pinOnEditProductKey) ?? false,
      'deleteProduct': prefs.getBool(_pinOnDeleteProductKey) ?? false,
      'settings': prefs.getBool(_pinOnSettingsKey) ?? false,
      'reports': prefs.getBool(_pinOnReportsKey) ?? false,
    };
  }

  Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setBool(_pinSetKey, false);
    await prefs.remove(_pinOnLoginKey);
    await prefs.remove(_pinOnAddProductKey);
    await prefs.remove(_pinOnEditProductKey);
    await prefs.remove(_pinOnDeleteProductKey);
    await prefs.remove(_pinOnSettingsKey);
    await prefs.remove(_pinOnReportsKey);
  }
}
