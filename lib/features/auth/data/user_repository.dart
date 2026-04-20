import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/app_user.dart';

/// Persistence for `users/{uid}` profile documents.
///
/// Kept narrow on purpose: only the operations the auth flow needs right now
/// (create-on-first-sign-in, watch, update). Session/queue features will get
/// their own repositories rather than overloading this one.
class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<AppUser?> fetch(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    return AppUser.fromFirestore(snap);
  }

  Stream<AppUser?> watch(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AppUser.fromFirestore(snap);
    });
  }

  /// Idempotent profile bootstrap. Called the first time a user authenticates
  /// so every authenticated UID always has a backing Firestore document.
  Future<void> ensureProfile(AppUser user) async {
    final ref = _users.doc(user.uid);
    final existing = await ref.get();
    if (existing.exists) return;
    await ref.set(user.toFirestore());
  }

  Future<void> update(AppUser user) async {
    await _users.doc(user.uid).set(
          user.toFirestore(),
          SetOptions(merge: true),
        );
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreProvider));
});
