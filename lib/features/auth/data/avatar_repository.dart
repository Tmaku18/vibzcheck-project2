import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

/// Uploads and resolves avatar images stored at `users/{uid}/avatar.<ext>`
/// in Firebase Storage.
///
/// We persist the storage *path* on the user's Firestore doc (not the
/// download URL) so clients can resolve fresh URLs on demand. This avoids
/// leaking signed-URL TTLs into Firestore documents.
class AvatarRepository {
  AvatarRepository(this._storage);

  final FirebaseStorage _storage;

  Reference _avatarRef(String uid, {String extension = 'jpg'}) {
    return _storage.ref().child('users/$uid/avatar.$extension');
  }

  /// Uploads [file] to `users/{uid}/avatar.jpg` and returns the storage
  /// path that the app can store on the user's Firestore profile.
  ///
  /// `image/jpeg` is hard-coded because Storage rules (see storage.rules)
  /// only permit image/* content types; the [ImagePicker] plugin produces
  /// JPEGs on Android, so this matches reality without needing a
  /// content-type sniffer.
  Future<String> uploadFromFile({
    required String uid,
    required File file,
  }) async {
    final ref = _avatarRef(uid);
    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.fullPath;
  }

  /// Resolves a short-lived download URL for display. Callers should treat
  /// the result as ephemeral and re-request it when refreshing the UI.
  Future<String> resolveDownloadUrl(String path) {
    return _storage.ref(path).getDownloadURL();
  }

  Future<void> deleteAvatar(String uid, {String extension = 'jpg'}) async {
    try {
      await _avatarRef(uid, extension: extension).delete();
    } on FirebaseException catch (e) {
      // `object-not-found` is expected when the user has never uploaded one.
      if (e.code != 'object-not-found') rethrow;
    }
  }
}

final avatarRepositoryProvider = Provider<AvatarRepository>((ref) {
  return AvatarRepository(ref.watch(firebaseStorageProvider));
});
