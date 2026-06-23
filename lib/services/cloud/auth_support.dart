import 'package:firebase_auth/firebase_auth.dart';

/// Result of a Firebase email/password auth attempt (login or sign-up),
/// shared by the phone-identity flow (`UserAuthService`) and the admin
/// flow (`AdminAuthService`).
///
/// Named distinctly from `ShopService.AuthResult`, which represents a
/// session-ensure outcome rather than a login attempt.
class AuthAttemptResult {
  final bool success;
  final String message;
  final String? uid;

  const AuthAttemptResult._({
    required this.success,
    required this.message,
    this.uid,
  });

  factory AuthAttemptResult.ok(String uid,
          [String message = 'Signed in.']) =>
      AuthAttemptResult._(success: true, message: message, uid: uid);

  factory AuthAttemptResult.fail(String message) =>
      AuthAttemptResult._(success: false, message: message);
}

/// Firebase enforces a 6-character minimum on email/password accounts.
const int kMinAuthPasswordLength = 6;

/// Maps a [FirebaseAuthException] to a user-facing message.
///
/// [credentialNoun] tailors the wording to the flow surfacing the error —
/// e.g. `'phone number'` for the phone identity flow or `'email'` for the
/// admin flow.
String readableFirebaseAuthError(
  FirebaseAuthException e, {
  required String credentialNoun,
  int minPasswordLength = kMinAuthPasswordLength,
}) {
  switch (e.code) {
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-email':
      return 'Incorrect $credentialNoun or password.';
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
