import 'package:flutter_test/flutter_test.dart';
import 'package:vibzcheck/features/recommendations/application/fairness_ranker.dart';
import 'package:vibzcheck/features/session/domain/queue_track.dart';
import 'package:vibzcheck/features/session/domain/track.dart';

QueueTrack _queueTrack({
  required String id,
  required String addedBy,
  String addedByName = 'Member',
  int voteScore = 0,
  DateTime? addedAt,
  bool played = false,
}) {
  return QueueTrack(
    id: 'mock_$id',
    sourceId: id,
    source: TrackSource.mock,
    title: id,
    artist: 'artist',
    album: 'album',
    durationMs: 180000,
    addedBy: addedBy,
    addedByName: addedByName,
    voteScore: voteScore,
    addedAt: addedAt,
    played: played,
  );
}

void main() {
  final fixedNow = DateTime.utc(2026, 4, 28, 12, 0, 0);
  final ranker = FairnessRanker(nowBuilder: () => fixedNow);

  test('empty queue returns empty ranking', () {
    expect(ranker.rank(const []), isEmpty);
  });

  test('equal vote counts -> under-represented member wins tie', () {
    // Alice contributes 3 tracks, Bob only 1. Both have voteScore 2.
    // Bob's track should beat Alice's on fairness.
    final queue = [
      _queueTrack(
        id: 'a1',
        addedBy: 'alice',
        addedByName: 'Alice',
        voteScore: 2,
        addedAt: fixedNow.subtract(const Duration(minutes: 5)),
      ),
      _queueTrack(
        id: 'a2',
        addedBy: 'alice',
        addedByName: 'Alice',
        voteScore: 0,
        addedAt: fixedNow.subtract(const Duration(minutes: 6)),
      ),
      _queueTrack(
        id: 'a3',
        addedBy: 'alice',
        addedByName: 'Alice',
        voteScore: 0,
        addedAt: fixedNow.subtract(const Duration(minutes: 7)),
      ),
      _queueTrack(
        id: 'b1',
        addedBy: 'bob',
        addedByName: 'Bob',
        voteScore: 2,
        addedAt: fixedNow.subtract(const Duration(minutes: 5)),
      ),
    ];

    final ranked = ranker.rank(queue);
    expect(ranked.first.track.sourceId, 'b1');
    expect(
      ranked.first.factors.any(
          (f) => f.label.toLowerCase().contains('fairness boost for bob')),
      isTrue,
    );
  });

  test('played tracks are penalised', () {
    final queue = [
      _queueTrack(
        id: 'played',
        addedBy: 'u1',
        voteScore: 5,
        played: true,
        addedAt: fixedNow,
      ),
      _queueTrack(
        id: 'fresh',
        addedBy: 'u2',
        voteScore: 5,
        addedAt: fixedNow,
      ),
    ];
    final ranked = ranker.rank(queue);
    expect(ranked.first.track.sourceId, 'fresh');
    final playedEntry =
        ranked.firstWhere((r) => r.track.sourceId == 'played');
    expect(playedEntry.factors.any((f) => f.weight < 0), isTrue);
  });

  test('recency contributes positive weight for just-added tracks', () {
    final queue = [
      _queueTrack(
        id: 'just-now',
        addedBy: 'u1',
        voteScore: 0,
        addedAt: fixedNow.subtract(const Duration(seconds: 5)),
      ),
    ];
    final ranked = ranker.rank(queue);
    final factors = ranked.single.factors;
    expect(
      factors.any((f) => f.label.toLowerCase().contains('fresh add')),
      isTrue,
    );
  });

  test('every ranked track exposes at least one factor (explainability)', () {
    final queue = [
      _queueTrack(
        id: 'a',
        addedBy: 'u1',
        voteScore: 1,
        addedAt: fixedNow,
      ),
      _queueTrack(
        id: 'b',
        addedBy: 'u2',
        voteScore: -1,
        addedAt: fixedNow,
      ),
    ];
    final ranked = ranker.rank(queue);
    for (final r in ranked) {
      expect(r.factors, isNotEmpty);
    }
  });
}
