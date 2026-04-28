import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibzcheck/features/session/data/queue_repository.dart';
import 'package:vibzcheck/features/session/domain/queue_track.dart';
import 'package:vibzcheck/features/session/domain/track.dart';

/// These tests drive `QueueRepository.castVote` (which runs inside a Firestore
/// transaction) against `FakeFirebaseFirestore` so we can validate the
/// denormalised `voteScore`, `upvotes`, `downvotes`, and per-user `votes` map
/// behaviour without hitting the real backend.
void main() {
  const sessionId = 'session-1';
  const trackDocId = 'mock_mock-test';
  const uidA = 'userA';
  const uidB = 'userB';

  late FakeFirebaseFirestore firestore;
  late QueueRepository repo;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repo = QueueRepository(firestore);
    await firestore
        .collection('sessions')
        .doc(sessionId)
        .set({'memberIds': [uidA, uidB]});
    await repo.addTrack(
      sessionId: sessionId,
      track: const Track(
        sourceId: 'mock-test',
        source: TrackSource.mock,
        title: 'Test Track',
        artist: 'Tester',
        album: 'Tests',
        durationMs: 180000,
      ),
      addedBy: uidA,
      addedByName: 'Alice',
    );
  });

  Future<QueueTrack> readTrack() async {
    final snap = await firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('queue')
        .doc(trackDocId)
        .get();
    return QueueTrack.fromFirestore(snap);
  }

  test('initial track starts with zero votes and zero score', () async {
    final track = await readTrack();
    expect(track.votes, isEmpty);
    expect(track.voteScore, 0);
    expect(track.upvotes, 0);
    expect(track.downvotes, 0);
  });

  test('single upvote raises voteScore and upvotes counter', () async {
    await repo.castVote(
      sessionId: sessionId,
      trackDocId: trackDocId,
      uid: uidA,
      direction: 1,
    );

    final track = await readTrack();
    expect(track.voteOf(uidA), 1);
    expect(track.voteScore, 1);
    expect(track.upvotes, 1);
    expect(track.downvotes, 0);
  });

  test('upvoting twice toggles the vote off', () async {
    await repo.castVote(
      sessionId: sessionId,
      trackDocId: trackDocId,
      uid: uidA,
      direction: 1,
    );
    await repo.castVote(
      sessionId: sessionId,
      trackDocId: trackDocId,
      uid: uidA,
      direction: 1,
    );

    final track = await readTrack();
    expect(track.voteOf(uidA), 0);
    expect(track.voteScore, 0);
    expect(track.upvotes, 0);
  });

  test('flipping from upvote to downvote overwrites in one step', () async {
    await repo.castVote(
      sessionId: sessionId,
      trackDocId: trackDocId,
      uid: uidA,
      direction: 1,
    );
    await repo.castVote(
      sessionId: sessionId,
      trackDocId: trackDocId,
      uid: uidA,
      direction: -1,
    );

    final track = await readTrack();
    expect(track.voteOf(uidA), -1);
    expect(track.voteScore, -1);
    expect(track.upvotes, 0);
    expect(track.downvotes, 1);
  });

  test('multiple users accumulate correctly without overwriting each other',
      () async {
    await repo.castVote(
      sessionId: sessionId,
      trackDocId: trackDocId,
      uid: uidA,
      direction: 1,
    );
    await repo.castVote(
      sessionId: sessionId,
      trackDocId: trackDocId,
      uid: uidB,
      direction: -1,
    );

    final track = await readTrack();
    expect(track.voteOf(uidA), 1);
    expect(track.voteOf(uidB), -1);
    expect(track.voteScore, 0);
    expect(track.upvotes, 1);
    expect(track.downvotes, 1);
  });

  test('castVote returns the effective vote (1, -1, or 0)', () async {
    final first = await repo.castVote(
      sessionId: sessionId,
      trackDocId: trackDocId,
      uid: uidA,
      direction: 1,
    );
    expect(first, 1);

    final toggledOff = await repo.castVote(
      sessionId: sessionId,
      trackDocId: trackDocId,
      uid: uidA,
      direction: 1,
    );
    expect(toggledOff, 0);

    final flipped = await repo.castVote(
      sessionId: sessionId,
      trackDocId: trackDocId,
      uid: uidA,
      direction: -1,
    );
    expect(flipped, -1);
  });

  test('voting on a missing track does not throw and returns 0', () async {
    final result = await repo.castVote(
      sessionId: sessionId,
      trackDocId: 'does-not-exist',
      uid: uidA,
      direction: 1,
    );
    expect(result, 0);
  });

  test('addTrack then watchQueue emits a list containing the track',
      () async {
    final stream = repo.watchQueue(sessionId);
    // fake_cloud_firestore emits the current state synchronously once a
    // listener is attached, so the first emission holds our seeded track.
    final first = await stream.first;
    expect(first, hasLength(1));
    expect(first.single.title, 'Test Track');
  });

  test('voteScore ordering reflects subsequent votes', () async {
    await repo.addTrack(
      sessionId: sessionId,
      track: const Track(
        sourceId: 'mock-other',
        source: TrackSource.mock,
        title: 'Other Track',
        artist: 'Someone',
        album: 'Tests',
        durationMs: 180000,
      ),
      addedBy: uidA,
      addedByName: 'Alice',
    );
    await repo.castVote(
      sessionId: sessionId,
      trackDocId: 'mock_mock-other',
      uid: uidA,
      direction: 1,
    );
    await repo.castVote(
      sessionId: sessionId,
      trackDocId: 'mock_mock-other',
      uid: uidB,
      direction: 1,
    );

    final queueSnap = await firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('queue')
        .orderBy('voteScore', descending: true)
        .get();
    expect(queueSnap.docs.first.id, 'mock_mock-other');
    expect((queueSnap.docs.first.data()['voteScore'] as num).toInt(), 2);
  });
}
