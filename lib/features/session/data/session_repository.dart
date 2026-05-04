import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/session.dart';
import '../domain/session_member.dart';

class SessionNotFoundException implements Exception {
  const SessionNotFoundException(this.code);
  final String code;
  @override
  String toString() => 'No session found for code $code.';
}

/// CRUD + lookup for `sessions/*` and the `members` subcollection.
class SessionRepository {
  SessionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection('sessions');

  /// Public mapping of `code -> {sessionId, ownerId}` so non-members can
  /// resolve a 6-character join code without us having to grant blanket
  /// read access on the whole `sessions` collection. See `firestore.rules`.
  CollectionReference<Map<String, dynamic>> get _joinCodes =>
      _firestore.collection('joinCodes');

  DocumentReference<Map<String, dynamic>> _sessionRef(String id) =>
      _sessions.doc(id);

  /// Creates a new session document *and* the owner's member doc in a single
  /// atomic batch. A random 6-character join code is generated client-side.
  /// We accept a tiny collision risk rather than reading the entire sessions
  /// collection on every create; callers can retry on the rare unique-index
  /// failure once Phase 4 tightens that constraint.
  Future<Session> createSession({
    required String ownerId,
    required String ownerName,
    required String title,
  }) async {
    final code = _generateCode();
    final ref = _sessions.doc();
    final now = DateTime.now();
    final session = Session(
      id: ref.id,
      ownerId: ownerId,
      ownerName: ownerName,
      title: title.trim(),
      code: code,
      status: SessionStatus.live,
      memberIds: [ownerId],
      memberCount: 1,
      createdAt: now,
      updatedAt: now,
    );

    final memberRef = ref.collection('members').doc(ownerId);
    final member = SessionMember(
      uid: ownerId,
      displayName: ownerName,
      role: SessionRole.owner,
      joinedAt: now,
    );

    final batch = _firestore.batch()
      ..set(ref, session.toFirestore())
      ..set(memberRef, member.toFirestore())
      ..set(_joinCodes.doc(code), {
        'sessionId': ref.id,
        'ownerId': ownerId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    await batch.commit();
    return session;
  }

  Stream<Session?> watchSession(String sessionId) {
    return _sessionRef(sessionId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Session.fromFirestore(snap);
    });
  }

  /// Reactive "sessions I'm in" list for the home screen. Backed by the
  /// `memberIds array-contains uid` query + composite index declared in
  /// `firestore.indexes.json`.
  Stream<List<Session>> watchSessionsForUser(String uid) {
    return _sessions
        .where('memberIds', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((query) =>
            query.docs.map((d) => Session.fromFirestore(d)).toList());
  }

  Stream<List<SessionMember>> watchMembers(String sessionId) {
    return _sessionRef(sessionId)
        .collection('members')
        .orderBy('joinedAt')
        .snapshots()
        .map((query) =>
            query.docs.map((d) => SessionMember.fromFirestore(d)).toList());
  }

  Future<Session> joinByCode({
    required String code,
    required String uid,
    required String displayName,
  }) async {
    final normalised = code.trim().toUpperCase();
    // Step 1: resolve code -> sessionId via the public mapping doc. Non-
    // members can't read the sessions collection directly, so this hop is
    // what makes "join by code" possible without weakening session privacy.
    final mapping = await _joinCodes.doc(normalised).get();
    if (!mapping.exists) {
      throw SessionNotFoundException(normalised);
    }
    final sessionId = mapping.data()?['sessionId'] as String?;
    if (sessionId == null) {
      throw SessionNotFoundException(normalised);
    }
    final sessionRef = _sessionRef(sessionId);

    // Step 2: add ourselves to the session in a single transaction. We
    // deliberately avoid `tx.get(sessionRef)` here: the read rule still
    // forbids non-members from reading the session body, and we don't need
    // to read it anyway because `arrayUnion` is idempotent. The
    // `memberCount` increment over-counts only if the same user joins twice
    // before the UI navigates away, which the join-screen flow prevents.
    await _firestore.runTransaction((tx) async {
      tx.update(sessionRef, {
        'memberIds': FieldValue.arrayUnion([uid]),
        'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        sessionRef.collection('members').doc(uid),
        SessionMember(
          uid: uid,
          displayName: displayName,
          role: SessionRole.member,
          joinedAt: DateTime.now(),
        ).toFirestore(),
      );
    });
    // Step 3: now that we're a member the read rule lets us pull the
    // refreshed session for the caller to navigate into.
    final refreshed = await sessionRef.get();
    return Session.fromFirestore(refreshed);
  }

  /// Members leave via a transaction so `memberIds`, `memberCount` and the
  /// `members/{uid}` doc stay consistent. The owner cannot leave with this
  /// method; they must end the session instead (Phase 3).
  Future<void> leaveSession({
    required String sessionId,
    required String uid,
  }) async {
    final ref = _sessionRef(sessionId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};
      if (data['ownerId'] == uid) {
        throw StateError('Owner cannot leave; end the session instead.');
      }
      final members =
          (data['memberIds'] as List?)?.whereType<String>().toSet() ??
              <String>{};
      members.remove(uid);
      tx.update(ref, {
        'memberIds': members.toList(),
        'memberCount': members.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.delete(ref.collection('members').doc(uid));
    });
  }

  Future<void> endSession(String sessionId) async {
    final snap = await _sessionRef(sessionId).get();
    final code = (snap.data() ?? const <String, dynamic>{})['code'] as String?;

    // Probe the public mapping before adding it to the batch. Sessions
    // created by older builds (pre-joinCodes) have no mapping doc, and
    // Firestore evaluates `delete` on a non-existent doc against
    // `resource = null` -- so the rule
    // `resource.data.ownerId == request.auth.uid` returns false and the
    // ENTIRE batch fails with PERMISSION_DENIED, leaving the owner unable
    // to end their own session. Skipping the delete when there's nothing
    // to delete keeps the operation idempotent on legacy data.
    var joinCodeExists = false;
    if (code != null && code.isNotEmpty) {
      try {
        final mapping = await _joinCodes.doc(code).get();
        joinCodeExists = mapping.exists;
      } on FirebaseException {
        // joinCodes is signed-in-readable, so this should never throw in
        // practice; if it does, fall through to the session-only update
        // rather than blocking the user.
        joinCodeExists = false;
      }
    }

    final batch = _firestore.batch()
      ..update(_sessionRef(sessionId), {
        'status': SessionStatus.ended.asString,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    if (joinCodeExists) {
      batch.delete(_joinCodes.doc(code!));
    }
    await batch.commit();
  }

  // 6-char codes use an unambiguous alphabet (no 0/O/1/I) so friends can
  // type them from a lock screen without mistakes.
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _rng = Random.secure();

  static String _generateCode() {
    return List.generate(
      6,
      (_) => _codeAlphabet[_rng.nextInt(_codeAlphabet.length)],
    ).join();
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(firestoreProvider));
});
