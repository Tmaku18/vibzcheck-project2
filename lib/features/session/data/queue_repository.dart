import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/queue_track.dart';
import '../domain/track.dart';

/// Reads and writes on `sessions/{sessionId}/queue/*`.
///
/// The voting method [castVote] is the core real-time piece of Vibzcheck. It
/// must stay **transaction-backed** so two users pressing upvote at the same
/// millisecond cannot corrupt the aggregate fields.
class QueueRepository {
  QueueRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _queueRef(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('queue');
  }

  DocumentReference<Map<String, dynamic>> _sessionRef(String sessionId) {
    return _firestore.collection('sessions').doc(sessionId);
  }

  /// Live queue ordered by `voteScore desc, addedAt asc` (backed by the
  /// composite index in `firestore.indexes.json`). Played tracks are
  /// excluded here and surfaced separately in Phase 3 once playback state
  /// is wired.
  Stream<List<QueueTrack>> watchQueue(String sessionId) {
    return _queueRef(sessionId)
        .where('played', isEqualTo: false)
        .orderBy('voteScore', descending: true)
        .orderBy('addedAt')
        .snapshots()
        .map((query) =>
            query.docs.map((d) => QueueTrack.fromFirestore(d)).toList());
  }

  /// Adds a track to the queue. We `set` onto a deterministic doc id
  /// (`<source>_<sourceId>`) so the same Spotify/mock track can't be added
  /// twice to the same session — a second call simply overwrites the prior
  /// metadata without resetting vote state because we pass `merge: true`.
  Future<void> addTrack({
    required String sessionId,
    required Track track,
    required String addedBy,
    required String addedByName,
  }) async {
    final docId = '${track.source.asString}_${track.sourceId}';
    final ref = _queueRef(sessionId).doc(docId);
    await ref.set(
      QueueTrack.creationPayload(
        track: track,
        addedBy: addedBy,
        addedByName: addedByName,
      ),
      SetOptions(merge: true),
    );
    await _sessionRef(sessionId).update({
      'queueCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeTrack({
    required String sessionId,
    required String trackDocId,
  }) async {
    await _queueRef(sessionId).doc(trackDocId).delete();
    await _sessionRef(sessionId).update({
      'queueCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Casts, flips, or clears the caller's vote on a queue track atomically.
  ///
  /// [direction] must be `+1` (upvote), `-1` (downvote), or `0` (clear).
  /// Rules:
  ///   * Voting the same direction twice toggles it off (returns to 0).
  ///   * Voting the opposite direction overwrites the prior vote in one step.
  ///   * Aggregates (`voteScore`, `upvotes`, `downvotes`) are recomputed
  ///     from the resulting votes map inside the transaction, so they
  ///     can never drift from the source-of-truth map.
  Future<int> castVote({
    required String sessionId,
    required String trackDocId,
    required String uid,
    required int direction,
  }) async {
    assert(direction == -1 || direction == 0 || direction == 1,
        'direction must be -1, 0, or 1');
    final ref = _queueRef(sessionId).doc(trackDocId);
    return _firestore.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return 0;
      final data = snap.data() ?? <String, dynamic>{};
      final rawVotes = data['votes'];
      final votes = <String, int>{};
      if (rawVotes is Map) {
        rawVotes.forEach((k, v) {
          if (k is String && v is num) votes[k] = v.toInt();
        });
      }
      final previous = votes[uid] ?? 0;

      int effective;
      if (direction == 0 || direction == previous) {
        votes.remove(uid);
        effective = 0;
      } else {
        votes[uid] = direction;
        effective = direction;
      }

      final score = votes.values.fold<int>(0, (a, b) => a + b);
      final up = votes.values.where((v) => v > 0).length;
      final down = votes.values.where((v) => v < 0).length;

      tx.update(ref, {
        'votes': votes,
        'voteScore': score,
        'upvotes': up,
        'downvotes': down,
      });
      return effective;
    });
  }
}

final queueRepositoryProvider = Provider<QueueRepository>((ref) {
  return QueueRepository(ref.watch(firestoreProvider));
});
