import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralised Riverpod providers that expose the Firebase SDK singletons.
///
/// Putting them behind providers keeps every feature module testable: tests
/// can override these providers with fakes (e.g. `FakeFirebaseFirestore`,
/// `MockFirebaseAuth`) without touching the real services.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

/// Cloud Functions are pinned to `us-central1` to match the default Firebase
/// region used during `firebase init`. Override the region here if the project
/// is later deployed elsewhere.
final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instanceFor(region: 'us-central1');
});

/// Stream of the currently authenticated [User]. Emits `null` when the user
/// is signed out. Used by the router and feature controllers to react to
/// authentication state without polling.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});
