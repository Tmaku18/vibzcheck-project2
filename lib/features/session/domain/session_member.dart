import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionRole { owner, member }

extension SessionRoleX on SessionRole {
  String get asString => name;

  static SessionRole parse(String? raw) {
    return SessionRole.values.firstWhere(
      (r) => r.name == raw,
      orElse: () => SessionRole.member,
    );
  }
}

/// Membership record at `sessions/{sessionId}/members/{uid}`.
///
/// Kept separate from the session document so thousands of presence/vote
/// updates don't rewrite the root session doc on every ping.
class SessionMember {
  const SessionMember({
    required this.uid,
    required this.displayName,
    required this.role,
    this.joinedAt,
    this.lastVoteAt,
  });

  final String uid;
  final String displayName;
  final SessionRole role;
  final DateTime? joinedAt;
  final DateTime? lastVoteAt;

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'role': role.asString,
      'joinedAt':
          joinedAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(joinedAt!),
      'lastVoteAt':
          lastVoteAt == null ? null : Timestamp.fromDate(lastVoteAt!),
    };
  }

  factory SessionMember.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return SessionMember(
      uid: snapshot.id,
      displayName: (data['displayName'] as String?) ?? 'Member',
      role: SessionRoleX.parse(data['role'] as String?),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
      lastVoteAt: (data['lastVoteAt'] as Timestamp?)?.toDate(),
    );
  }
}
