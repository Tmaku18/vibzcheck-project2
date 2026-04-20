import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// Stateless controller exposed to the UI for sign-in / sign-up / sign-out.
///
/// The controller intentionally returns plain `Future`s instead of holding
/// loading state so screens can render their own button-level spinners and
/// scoped error messages with a `try/catch`.
class AuthController {
  AuthController(this._repository);

  final AuthRepository _repository;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _repository.signIn(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _repository.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  Future<void> signOut() => _repository.signOut();

  Future<void> sendPasswordResetEmail(String email) {
    return _repository.sendPasswordResetEmail(email);
  }
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

/// Maps `FirebaseAuthException`s to a one-line, user-friendly string so we
/// never leak raw stack traces to the UI.
String describeFirebaseAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return error.message ?? 'Authentication failed (${error.code}).';
    }
  }
  return 'Unexpected error: $error';
}
