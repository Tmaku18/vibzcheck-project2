import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/app_user.dart';
import 'user_repository.dart';

/// Thin wrapper around [FirebaseAuth] that exposes only the operations the
/// UI needs and bridges into [UserRepository] so a Firestore profile is
/// always created on first sign-up.
class AuthRepository {
  AuthRepository(this._auth, this._userRepository);

  final FirebaseAuth _auth;
  final UserRepository _userRepository;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Create the FirebaseAuth user, set the display name, and bootstrap the
  /// matching Firestore profile in a single call so callers never have to
  /// remember to do it themselves.
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      await user.updateDisplayName(displayName.trim());
      await _userRepository.ensureProfile(
        AppUser(
          uid: user.uid,
          email: user.email ?? email.trim(),
          displayName: displayName.trim(),
        ),
      );
    }
    return credential;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(userRepositoryProvider),
  );
});
