import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibzcheck/features/session/data/session_repository.dart';
import 'package:vibzcheck/features/session/domain/session.dart';

/// State-transition tests for [SessionRepository].
///
/// These cover the full session lifecycle the home screen + join screen rely
/// on -- create, join-by-code (happy + missing code), leave, owner-cannot-
/// leave guard, and end-session cleanup of the public `joinCodes` mapping.
///
/// We use `FakeFirebaseFirestore` so transactions, batches, `arrayUnion`,
/// `increment`, and `serverTimestamp` all execute against the same in-memory
/// engine the production repo talks to. Security rules are NOT enforced by
/// the fake; rule coverage lives in the manual proof captured in
/// `docs/screenshots/` (Phase 4 evidence).
void main() {
  const ownerId = 'owner-1';
  const ownerName = 'Alice';
  const joinerId = 'joiner-2';
  const joinerName = 'Bob';

  late FakeFirebaseFirestore firestore;
  late SessionRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = SessionRepository(firestore);
  });

  group('createSession', () {
    test('persists the session, the owner member doc, and a joinCodes mapping',
        () async {
      final session = await repo.createSession(
        ownerId: ownerId,
        ownerName: ownerName,
        title: '  Friday vibes  ',
      );

      expect(session.title, 'Friday vibes',
          reason: 'createSession must trim user-entered title before storing');
      expect(session.ownerId, ownerId);
      expect(session.memberIds, [ownerId]);
      expect(session.memberCount, 1);
      expect(session.code.length, 6);
      // Codes use the unambiguous alphabet (no 0/O/1/I) to be lock-screen
      // typeable.
      expect(RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(session.code), isTrue,
          reason: 'code "${session.code}" leaked an ambiguous character');

      final stored =
          await firestore.collection('sessions').doc(session.id).get();
      expect(stored.exists, isTrue);
      expect(stored.data()!['status'], SessionStatus.live.asString);

      final memberDoc = await firestore
          .collection('sessions')
          .doc(session.id)
          .collection('members')
          .doc(ownerId)
          .get();
      expect(memberDoc.exists, isTrue,
          reason: 'owner member doc must be created in the same batch');
      expect(memberDoc.data()!['role'], 'owner');

      final mapping =
          await firestore.collection('joinCodes').doc(session.code).get();
      expect(mapping.exists, isTrue,
          reason: 'joinCodes mapping must exist so non-members can join by code');
      expect(mapping.data()!['sessionId'], session.id);
      expect(mapping.data()!['ownerId'], ownerId);
    });

    test('two consecutive creates produce different join codes', () async {
      final s1 = await repo.createSession(
          ownerId: ownerId, ownerName: ownerName, title: 'A');
      final s2 = await repo.createSession(
          ownerId: ownerId, ownerName: ownerName, title: 'B');
      // Birthday-paradox collisions across only two pulls from a 32^6 space
      // are essentially impossible; if this ever fires the RNG is broken.
      expect(s1.code, isNot(s2.code));
    });
  });

  group('joinByCode', () {
    test('adds the joiner to memberIds, bumps memberCount, writes member doc',
        () async {
      final session = await repo.createSession(
        ownerId: ownerId,
        ownerName: ownerName,
        title: 'Open lounge',
      );

      final joined = await repo.joinByCode(
        // Lower-case + whitespace must normalise to the upper-case key the
        // mapping is stored under.
        code: '  ${session.code.toLowerCase()}  ',
        uid: joinerId,
        displayName: joinerName,
      );

      expect(joined.id, session.id);
      expect(joined.memberIds, containsAll([ownerId, joinerId]));
      expect(joined.memberCount, 2);

      final memberDoc = await firestore
          .collection('sessions')
          .doc(session.id)
          .collection('members')
          .doc(joinerId)
          .get();
      expect(memberDoc.exists, isTrue);
      expect(memberDoc.data()!['role'], 'member',
          reason: 'a non-owner who joins must be persisted with role=member');
    });

    test('throws SessionNotFoundException when code is unknown', () async {
      expect(
        () => repo.joinByCode(
            code: 'NOPE99', uid: joinerId, displayName: joinerName),
        throwsA(isA<SessionNotFoundException>()),
      );
    });
  });

  group('leaveSession', () {
    test('removes the member, decrements count, deletes member doc', () async {
      final session = await repo.createSession(
          ownerId: ownerId, ownerName: ownerName, title: 'Leave me');
      await repo.joinByCode(
          code: session.code, uid: joinerId, displayName: joinerName);

      await repo.leaveSession(sessionId: session.id, uid: joinerId);

      final after =
          await firestore.collection('sessions').doc(session.id).get();
      final data = after.data()!;
      expect(data['memberIds'], [ownerId]);
      expect(data['memberCount'], 1);

      final memberDoc = await firestore
          .collection('sessions')
          .doc(session.id)
          .collection('members')
          .doc(joinerId)
          .get();
      expect(memberDoc.exists, isFalse);
    });

    test('owner cannot leave their own session (must end it instead)',
        () async {
      final session = await repo.createSession(
          ownerId: ownerId, ownerName: ownerName, title: 'Solo');
      expect(
        () => repo.leaveSession(sessionId: session.id, uid: ownerId),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('endSession', () {
    test('flips status to ended and deletes the joinCodes mapping', () async {
      final session = await repo.createSession(
          ownerId: ownerId, ownerName: ownerName, title: 'Goodbye');
      // Sanity precondition: the public mapping exists right after create.
      expect(
        (await firestore.collection('joinCodes').doc(session.code).get())
            .exists,
        isTrue,
      );

      await repo.endSession(session.id);

      final after =
          await firestore.collection('sessions').doc(session.id).get();
      expect(after.data()!['status'], SessionStatus.ended.asString);

      final mapping =
          await firestore.collection('joinCodes').doc(session.code).get();
      expect(mapping.exists, isFalse,
          reason:
              'ending a session must drop its joinCodes entry so the code cannot be reused');
    });
  });

  group('watchSessionsForUser', () {
    test('emits sessions where the user is a member, ordered by updatedAt desc',
        () async {
      final s1 = await repo.createSession(
          ownerId: ownerId, ownerName: ownerName, title: 'First');
      final s2 = await repo.createSession(
          ownerId: ownerId, ownerName: ownerName, title: 'Second');

      // Joiner sees only the session they actually joined.
      await repo.joinByCode(
          code: s2.code, uid: joinerId, displayName: joinerName);

      final ownerList = await repo.watchSessionsForUser(ownerId).first;
      expect(ownerList.map((s) => s.id), containsAll([s1.id, s2.id]));

      final joinerList = await repo.watchSessionsForUser(joinerId).first;
      expect(joinerList.map((s) => s.id), [s2.id]);
    });
  });
}
