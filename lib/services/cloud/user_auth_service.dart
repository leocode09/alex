import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_init.dart';
import 'firestore_paths.dart';

/// Result of a phone + password auth attempt.
class UserAuthResult {
  final bool success;
  final String message;
  final String? uid;

  const UserAuthResult._({
    required this.success,
    required this.message,
    this.uid,
  });

  factory UserAuthResult.ok(String uid, [String message = 'Signed in.']) =>
      UserAuthResult._(success: true, message: message, uid: uid);

  factory UserAuthResult.fail(String message) =>
      UserAuthResult._(success: false, message: message);
}

/// Stable phone + password identity for device users.
///
/// Implementation detail: Firebase has no native "phone + password"
/// provider without SMS, so we map the normalized phone number to a
/// synthetic email (`<phoneKey>@phone.alex-pos.app`) and use the native
/// email/password provider. This gives each phone a permanent, stable
/// Firebase uid that survives reinstalls / new devices — which is what
/// makes shop ownership reliable. No SMS, no backend, no hand-rolled
/// password hashing (Firebase handles it).
///
/// Password reset is intentionally out of band: a super admin resets a
/// password from the Firebase console (the synthetic email cannot
/// receive a reset link).
class UserAuthService {
  UserAuthService._internal();
  static final UserAuthService _instance = UserAuthService._internal();
  factory UserAuthService() => _instance;

  /// Synthetic email domain. Never receives mail — it only exists so the
  /// email/password provider can key accounts by phone.
  static const String _emailDomain = 'phone.alex-pos.app';

  /// Default country code prepended to local numbers that start with `0`.
  /// Matches the deployment region (Rwanda / +250). Numbers entered in
  /// full international form are preserved.
  static const String _defaultCountryCode = '250';

  /// Firebase enforces a 6-character minimum on email/password accounts.
  static const int minPasswordLength = 6;

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  bool get isSignedIn => FirebaseAuth.instance.currentUser != null;

  /// Emits on login / logout so listeners can re-resolve account state.
  Stream<User?> authStateChanges() =>
      FirebaseAuth.instance.authStateChanges();

  /// Normalizes a raw phone into a digits-only key used as the account
  /// identity. Local numbers (`07...`) are expanded with the default
  /// country code so the same person resolves to the same key regardless
  /// of how they typed it.
  String normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    // Strip an international 00 prefix (e.g. 0025078...).
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      // Local form: drop the trunk 0 and prepend the country code.
      digits = '$_defaultCountryCode${digits.substring(1)}';
    }
    return digits;
  }

  String syntheticEmail(String phoneKey) => '$phoneKey@$_emailDomain';

  /// True when two phone strings refer to the same number, tolerant of
  /// formatting differences (compares the trailing significant digits).
  /// Used when matching against legacy `ownerPhone` values.
  static bool phonesMatch(String a, String b) {
    final da = a.replaceAll(RegExp(r'\D'), '');
    final db = b.replaceAll(RegExp(r'\D'), '');
    if (da.isEmpty || db.isEmpty) return false;
    final tailLen = da.length < db.length ? da.length : db.length;
    final n = tailLen < 9 ? tailLen : 9;
    return da.substring(da.length - n) == db.substring(db.length - n);
  }

  /// The logged-in user's phone, read from their `/users/{uid}` doc.
  Future<String?> currentPhone() async {
    final uid = currentUid;
    if (uid == null || !FirebaseInit.available) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.usersCollection)
          .doc(uid)
          .get();
      return snap.data()?['phone'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Creates a new phone + password account and its `/users/{uid}` doc.
  Future<UserAuthResult> register({
    required String phone,
    required String password,
    required String displayName,
  }) async {
    if (!FirebaseInit.available) {
      return UserAuthResult.fail(
        'Cloud is not configured on this device. Accounts require '
        'Firebase to be set up.',
      );
    }
    final rawPhone = phone.trim();
    final phoneKey = normalizePhone(rawPhone);
    final name = displayName.trim();
    if (phoneKey.length < 9) {
      return UserAuthResult.fail('Enter a valid phone number.');
    }
    if (name.isEmpty) {
      return UserAuthResult.fail('Your name is required.');
    }
    if (password.length < minPasswordLength) {
      return UserAuthResult.fail(
        'Password must be at least $minPasswordLength characters.',
      );
    }

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: syntheticEmail(phoneKey),
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        return UserAuthResult.fail('Sign-up failed. Please try again.');
      }
      await _writeUserDoc(
        uid: uid,
        phone: rawPhone,
        phoneKey: phoneKey,
        displayName: name,
      );
      return UserAuthResult.ok(uid, 'Account created.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return UserAuthResult.fail(
          'An account already exists for this phone number. Log in '
          'instead.',
        );
      }
      return UserAuthResult.fail(_readableError(e));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserAuthService.register error: $e');
      }
      return UserAuthResult.fail('Sign-up failed: $e');
    }
  }

  /// Logs in with phone + password.
  Future<UserAuthResult> login({
    required String phone,
    required String password,
  }) async {
    if (!FirebaseInit.available) {
      return UserAuthResult.fail(
        'Cloud is not configured on this device.',
      );
    }
    final rawPhone = phone.trim();
    final phoneKey = normalizePhone(rawPhone);
    if (phoneKey.length < 9) {
      return UserAuthResult.fail('Enter a valid phone number.');
    }
    if (password.isEmpty) {
      return UserAuthResult.fail('Password is required.');
    }

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: syntheticEmail(phoneKey),
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        return UserAuthResult.fail('Login failed. Please try again.');
      }
      // Keep the profile doc fresh (e.g. phone formatting) without
      // clobbering shopId/role/displayName.
      await _writeUserDoc(
        uid: uid,
        phone: rawPhone,
        phoneKey: phoneKey,
      );
      return UserAuthResult.ok(uid);
    } on FirebaseAuthException catch (e) {
      return UserAuthResult.fail(_readableError(e));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserAuthService.login error: $e');
      }
      return UserAuthResult.fail('Login failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserAuthService.signOut error: $e');
      }
    }
  }

  /// Records a best-effort pointer to the user's current shop so a fresh
  /// device can restore membership after login.
  Future<void> setShopMembership({
    required String shopId,
    required String role,
  }) async {
    final uid = currentUid;
    if (uid == null || !FirebaseInit.available) return;
    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.usersCollection)
          .doc(uid)
          .set({
        'shopId': shopId,
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserAuthService.setShopMembership error: $e');
      }
    }
  }

  /// The stored shop pointer for the logged-in user, if any.
  Future<String?> storedShopId() async {
    final uid = currentUid;
    if (uid == null || !FirebaseInit.available) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.usersCollection)
          .doc(uid)
          .get();
      final id = snap.data()?['shopId'] as String?;
      return (id != null && id.isNotEmpty) ? id : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeUserDoc({
    required String uid,
    required String phone,
    required String phoneKey,
    String? displayName,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.usersCollection)
          .doc(uid)
          .set({
        'phone': phone,
        'phoneKey': phoneKey,
        if (displayName != null && displayName.isNotEmpty)
          'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserAuthService._writeUserDoc error: $e');
      }
    }
  }

  String _readableError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect phone number or password.';
      case 'invalid-email':
        return 'Enter a valid phone number.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'No internet connection reached Firebase. Check your '
            'connection and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled in the Firebase '
            'project. Enable it in Authentication settings.';
      case 'weak-password':
        return 'Password must be at least $minPasswordLength characters.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }
}
