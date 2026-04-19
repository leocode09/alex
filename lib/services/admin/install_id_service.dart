import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Per-install stable UUID. Generated on first boot and never changes
/// for the lifetime of the install.
///
/// Used by the super admin to identify every device that has ever run
/// the app, independent of the Firebase anonymous uid (which rotates if
/// app data is cleared) and independent of shop membership.
class InstallIdService {
  InstallIdService._();

  static const String _prefsKey = 'install_id';
  static const Uuid _uuid = Uuid();
  static String? _cached;

  /// Returns the install id, creating and persisting it the first time
  /// this is called. Safe to call from any isolate.
  static Future<String> ensure() async {
    if (_cached != null) {
      return _cached!;
    }
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsKey);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }
    final generated = _uuid.v4();
    await prefs.setString(_prefsKey, generated);
    _cached = generated;
    return generated;
  }

  /// Synchronous accessor for code paths that only need the id after
  /// [ensure] has been awaited. Returns null if [ensure] was never
  /// called.
  static String? get cached => _cached;
}
