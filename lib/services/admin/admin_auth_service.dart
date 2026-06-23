import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../cloud/auth_support.dart';
import '../cloud/firebase_init.dart';
import '../cloud/firestore_paths.dart';

/// Authenticates a super admin against Firebase, but keeps the session
/// *separate* from the device's anonymous auth session.
///
/// Implementation:
///   - Initializes a second Firebase app instance (named "admin") that
///     is backed by the same project. `FirebaseAuth.instanceFor(...)`
///     then gives us an isolated auth context so signing in as admin
///     never overwrites the device's install-bound uid that drives
///     /devices/{installId} and usage tracking.
///   - On sign-in, looks up `/admins/{uid}` using the named instance's
///     Firestore. Non-allowlisted accounts are signed out immediately.
///
/// Persistence is in-memory only: admins must re-authenticate on each
/// process restart so a lost device can't stay in admin mode.
class AdminAuthService {
  AdminAuthService._internal();
  static final AdminAuthService _instance = AdminAuthService._internal();
  factory AdminAuthService() => _instance;

  static const String _adminAppName = 'admin';

  FirebaseAuth? _auth;
  FirebaseFirestore? _db;

  String? _uid;
  String? _email;
  bool _ready = false;
  bool _initializing = false;

  String? get currentUid => _uid;
  String? get currentEmail => _email;
  bool get isSignedIn => _uid != null;

  /// True iff Firebase is available at all. The admin flow cannot work
  /// on platforms / configurations where [FirebaseInit.available] is
  /// false.
  bool get available => FirebaseInit.available;

  Future<void> _ensureApp() async {
    if (_ready) {
      return;
    }
    if (_initializing) {
      // Busy-wait briefly so concurrent callers don't double-init.
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return;
    }
    _initializing = true;
    try {
      if (!FirebaseInit.available) {
        return;
      }

      FirebaseApp? app;
      try {
        app = Firebase.app(_adminAppName);
      } on FirebaseException {
        app = null;
      } catch (_) {
        app = null;
      }

      app ??= await Firebase.initializeApp(
        name: _adminAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );

      _auth = FirebaseAuth.instanceFor(app: app);
      _db = FirebaseFirestore.instanceFor(app: app);
      _ready = true;

      // If the named instance already has a signed-in admin from an
      // earlier session in this process, preserve it.
      final existing = _auth!.currentUser;
      if (existing != null) {
        _uid = existing.uid;
        _email = existing.email;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AdminAuthService init error: $e');
      }
    } finally {
      _initializing = false;
    }
  }

  Future<AuthAttemptResult> signIn({
    required String email,
    required String password,
  }) async {
    if (!available) {
      return AuthAttemptResult.fail(
        'Cloud is not configured on this device. '
        'Run `flutterfire configure` to enable the admin panel.',
      );
    }
    await _ensureApp();
    final auth = _auth;
    final db = _db;
    if (auth == null || db == null) {
      return AuthAttemptResult.fail('Admin auth is unavailable.');
    }
    final cleanedEmail = email.trim();
    if (cleanedEmail.isEmpty) {
      return AuthAttemptResult.fail('Email is required.');
    }
    if (password.isEmpty) {
      return AuthAttemptResult.fail('Password is required.');
    }

    try {
      final cred = await auth.signInWithEmailAndPassword(
        email: cleanedEmail,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        return AuthAttemptResult.fail('Sign-in failed.');
      }
      final uid = user.uid;

      // Allowlist check. Non-admin accounts are signed out so we never
      // leave a user "partly signed in".
      final doc = await db
          .collection(FirestorePaths.adminsCollection)
          .doc(uid)
          .get();
      if (!doc.exists) {
        await auth.signOut();
        return AuthAttemptResult.fail(
          'This account is not authorized for admin access.',
        );
      }

      _uid = uid;
      _email = user.email;
      return AuthAttemptResult.ok(uid);
    } on FirebaseAuthException catch (e) {
      return AuthAttemptResult.fail(
        readableFirebaseAuthError(e, credentialNoun: 'email'),
      );
    } catch (e) {
      return AuthAttemptResult.fail('Unexpected error: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (_) {
      // ignore
    }
    _uid = null;
    _email = null;
  }

  /// Firestore instance bound to the admin's auth context. Admin-only
  /// screens must use this instance (not the default one) so security
  /// rules see the admin uid instead of the device's anonymous uid.
  FirebaseFirestore? get db => _db;
}
