import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle state of a Vibzcheck listening session.
enum SessionStatus { live, paused, ended }

extension SessionStatusX on SessionStatus {
  String get asString => name;

  static SessionStatus parse(String? raw) {
    return SessionStatus.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => SessionStatus.live,
    );
  }
}

/// A Vibzcheck listening session, persisted at `sessions/{sessionId}`.
///
/// The [memberIds] array on this root document enables a single
/// `array-contains` query to list every session the current user has joined,
/// which keeps the home screen cheap and avoids a collection-group query
/// over the `members` subcollection.
class Session {
  const Session({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.code,
    required this.status,
    required this.memberIds,
    this.currentTrackId,
    this.moodSummary,
    this.memberCount = 1,
    this.queueCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String title;

  /// 6-character alphanumeric join code shown to friends.
  final String code;

  final SessionStatus status;
  final List<String> memberIds;
  final String? currentTrackId;
  final String? moodSummary;
  final int memberCount;
  final int queueCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool isOwner(String uid) => ownerId == uid;
  bool isMember(String uid) => memberIds.contains(uid);

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'title': title,
      'code': code,
      'status': status.asString,
      'memberIds': memberIds,
      'currentTrackId': currentTrackId,
      'moodSummary': moodSummary,
      'memberCount': memberCount,
      'queueCount': queueCount,
      'createdAt':
          createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Session.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return Session(
      id: snapshot.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      ownerName: (data['ownerName'] as String?) ?? '',
      title: (data['title'] as String?) ?? 'Untitled session',
      code: (data['code'] as String?) ?? '',
      status: SessionStatusX.parse(data['status'] as String?),
      memberIds:
          (data['memberIds'] as List?)?.whereType<String>().toList() ?? const [],
      currentTrackId: data['currentTrackId'] as String?,
      moodSummary: data['moodSummary'] as String?,
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
      queueCount: (data['queueCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
