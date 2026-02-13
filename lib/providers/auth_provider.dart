import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<bool>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<bool>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      state = AsyncValue.data(isLoggedIn);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      // Save login status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', email);

      state = const AsyncValue.data(true);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      state = const AsyncValue.data(false);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
