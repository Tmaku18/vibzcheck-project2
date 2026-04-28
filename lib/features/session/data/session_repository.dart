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
      ..set(memberRef, member.toFirestore());
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
    final query = await _sessions
        .where('code', isEqualTo: normalised)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      throw SessionNotFoundException(normalised);
    }
    final sessionDoc = query.docs.first;
    await _firestore.runTransaction((tx) async {
      final fresh = await tx.get(sessionDoc.reference);
      final data = fresh.data() ?? <String, dynamic>{};
      final members =
          (data['memberIds'] as List?)?.whereType<String>().toSet() ??
              <String>{};
      if (!members.contains(uid)) {
        members.add(uid);
        tx.update(sessionDoc.reference, {
          'memberIds': members.toList(),
          'memberCount': members.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.set(
        sessionDoc.reference.collection('members').doc(uid),
        SessionMember(
          uid: uid,
          displayName: displayName,
          role: SessionRole.member,
          joinedAt: DateTime.now(),
        ).toFirestore(),
      );
    });
    final refreshed = await sessionDoc.reference.get();
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
    await _sessionRef(sessionId).update({
      'status': SessionStatus.ended.asString,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
