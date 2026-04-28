import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/queue_repository.dart';
import '../data/session_repository.dart';
import '../domain/session.dart';
import '../domain/track.dart';

/// Command-side operations on sessions/queues, grouped so screens don't
/// have to juggle four repositories.
class SessionController {
  SessionController({
    required SessionRepository sessionRepository,
    required QueueRepository queueRepository,
    required String Function() getUid,
    required String Function() getDisplayName,
  })  : _sessionRepository = sessionRepository,
        _queueRepository = queueRepository,
        _getUid = getUid,
        _getDisplayName = getDisplayName;

  final SessionRepository _sessionRepository;
  final QueueRepository _queueRepository;
  final String Function() _getUid;
  final String Function() _getDisplayName;

  Future<Session> createSession({required String title}) {
    return _sessionRepository.createSession(
      ownerId: _getUid(),
      ownerName: _getDisplayName(),
      title: title,
    );
  }

  Future<Session> joinByCode(String code) {
    return _sessionRepository.joinByCode(
      code: code,
      uid: _getUid(),
      displayName: _getDisplayName(),
    );
  }

  Future<void> leave(String sessionId) {
    return _sessionRepository.leaveSession(
      sessionId: sessionId,
      uid: _getUid(),
    );
  }

  Future<void> end(String sessionId) =>
      _sessionRepository.endSession(sessionId);

  Future<void> addTrack({
    required String sessionId,
    required Track track,
  }) {
    return _queueRepository.addTrack(
      sessionId: sessionId,
      track: track,
      addedBy: _getUid(),
      addedByName: _getDisplayName(),
    );
  }

  Future<void> removeTrack({
    required String sessionId,
    required String trackDocId,
  }) {
    return _queueRepository.removeTrack(
      sessionId: sessionId,
      trackDocId: trackDocId,
    );
  }

  Future<int> castVote({
    required String sessionId,
    required String trackDocId,
    required int direction,
  }) {
    return _queueRepository.castVote(
      sessionId: sessionId,
      trackDocId: trackDocId,
      uid: _getUid(),
      direction: direction,
    );
  }
}

final sessionControllerProvider = Provider<SessionController>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return SessionController(
    sessionRepository: ref.watch(sessionRepositoryProvider),
    queueRepository: ref.watch(queueRepositoryProvider),
    getUid: () {
      final u = auth.currentUser;
      if (u == null) {
        throw StateError('SessionController used while signed out.');
      }
      return u.uid;
    },
    getDisplayName: () {
      final u = auth.currentUser;
      final name = u?.displayName?.trim();
      if (name != null && name.isNotEmpty) return name;
      final email = u?.email;
      if (email != null && email.isNotEmpty) return email.split('@').first;
      return 'Member';
    },
  );
});
