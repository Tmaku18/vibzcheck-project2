import 'package:flutter_test/flutter_test.dart';
import 'package:vibzcheck/features/recommendations/application/track_recommender.dart';
import 'package:vibzcheck/features/session/domain/queue_track.dart';
import 'package:vibzcheck/features/session/domain/track.dart';

Track _track(
  String id, {
  List<String> moodTags = const [],
}) {
  return Track(
    sourceId: id,
    source: TrackSource.mock,
    title: id,
    artist: 'artist',
    album: 'album',
    durationMs: 180000,
    moodTags: moodTags,
  );
}

QueueTrack _queueTrack(
  String id, {
  List<String> moodTags = const [],
  int voteScore = 0,
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
    addedBy: 'u1',
    addedByName: 'Alice',
    moodTags: moodTags,
    voteScore: voteScore,
    played: played,
  );
}

void main() {
  const recommender = TrackRecommender();

  test('empty catalogue returns empty list', () {
    expect(
      recommender.recommendNext(queue: const [], catalogue: const []),
      isEmpty,
    );
  });

  test('excludes tracks already in the queue', () {
    final catalogue = [
      _track('a'),
      _track('b'),
      _track('c'),
    ];
    final queue = [_queueTrack('a')];
    final results = recommender.recommendNext(
      queue: queue,
      catalogue: catalogue,
    );
    expect(results.map((s) => s.track.sourceId), isNot(contains('a')));
  });

  test('mood match boosts a track strongly', () {
    final catalogue = [
      _track('a', moodTags: ['chill']),
      _track('b', moodTags: ['hype']),
    ];
    final queue = [
      _queueTrack('seed1', moodTags: ['chill'], voteScore: 3),
      _queueTrack('seed2', moodTags: ['chill'], voteScore: 2),
    ];
    final results = recommender.recommendNext(
      queue: queue,
      catalogue: catalogue,
      topK: 2,
    );
    expect(results.first.track.sourceId, 'a');
    expect(
      results.first.factors.map((f) => f.label),
      contains('Matches room mood (#chill)'),
    );
  });

  test('returns at most topK suggestions', () {
    final catalogue = [for (final c in ['a', 'b', 'c', 'd', 'e']) _track(c)];
    final results = recommender.recommendNext(
      queue: const [],
      catalogue: catalogue,
      topK: 3,
    );
    expect(results, hasLength(3));
  });

  test('every suggestion has at least one explainable factor', () {
    final catalogue = [_track('a'), _track('b'), _track('c')];
    final results = recommender.recommendNext(
      queue: const [],
      catalogue: catalogue,
    );
    for (final s in results) {
      expect(s.factors, isNotEmpty,
          reason: 'explainability is the core rubric bullet');
    }
  });

  test('stale queue (all played) still returns suggestions with fresh energy',
      () {
    final catalogue = [_track('new')];
    final queue = [_queueTrack('seed', played: true)];
    final results = recommender.recommendNext(
      queue: queue,
      catalogue: catalogue,
    );
    expect(results.first.factors.any((f) =>
            f.label.toLowerCase().contains('fresh')),
        isTrue);
  });
}
