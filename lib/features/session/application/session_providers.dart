import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../data/queue_repository.dart';
import '../data/session_repository.dart';
import '../domain/queue_track.dart';
import '../domain/session.dart';
import '../domain/session_member.dart';

/// Central place for Riverpod providers that watch Firestore on behalf of
/// the session UI. Keeping them here (rather than in screens) means the
/// same stream is multicast for every subscriber and correctly cancelled
/// when no screen is listening.

/// Live list of sessions the current authenticated user belongs to.
final mySessionsProvider = StreamProvider<List<Session>>((ref) {
  final auth = ref.watch(authStateChangesProvider).value;
  if (auth == null) return const Stream.empty();
  return ref.watch(sessionRepositoryProvider).watchSessionsForUser(auth.uid);
});

/// Live snapshot of a single session doc.
final sessionByIdProvider =
    StreamProvider.family<Session?, String>((ref, sessionId) {
  return ref.watch(sessionRepositoryProvider).watchSession(sessionId);
});

/// Live member list for a session.
final sessionMembersProvider =
    StreamProvider.family<List<SessionMember>, String>((ref, sessionId) {
  return ref.watch(sessionRepositoryProvider).watchMembers(sessionId);
});

/// Live ordered queue (voteScore desc, then addedAt asc).
final sessionQueueProvider =
    StreamProvider.family<List<QueueTrack>, String>((ref, sessionId) {
  return ref.watch(queueRepositoryProvider).watchQueue(sessionId);
});

/// Profile document for the signed-in user. Used by screens that need the
/// display name for session creation / joins.
final currentUserProfileProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authStateChangesProvider).value;
  if (auth == null) return const Stream.empty();
  return ref.watch(userRepositoryProvider).watch(auth.uid);
});
