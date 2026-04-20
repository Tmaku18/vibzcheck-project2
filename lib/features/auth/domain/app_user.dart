import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain representation of a Vibzcheck user, persisted at `users/{uid}`.
///
/// Kept as a plain immutable Dart class (no code generation) so the data
/// model is easy to reason about during the demo and easy to defend in the
/// curated questions ("how is your data modeled?").
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.avatarPath,
    this.favoriteGenres = const <String>[],
    this.notificationsEnabled = true,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String email;
  final String displayName;

  /// Storage path (not URL) of the user's avatar in Firebase Storage. Storing
  /// the path keeps the document small and lets us regenerate signed URLs on
  /// demand if rules ever require it.
  final String? avatarPath;
  final List<String> favoriteGenres;
  final bool notificationsEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasCompletedProfile => displayName.trim().isNotEmpty;

  AppUser copyWith({
    String? displayName,
    String? avatarPath,
    List<String>? favoriteGenres,
    bool? notificationsEnabled,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarPath: avatarPath ?? this.avatarPath,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'avatarPath': avatarPath,
      'favoriteGenres': favoriteGenres,
      'notificationsEnabled': notificationsEnabled,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: snapshot.id,
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      avatarPath: data['avatarPath'] as String?,
      favoriteGenres:
          (data['favoriteGenres'] as List?)?.whereType<String>().toList() ??
              const <String>[],
      notificationsEnabled:
          (data['notificationsEnabled'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
