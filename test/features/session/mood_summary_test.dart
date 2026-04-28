import 'package:flutter_test/flutter_test.dart';
import 'package:vibzcheck/features/session/application/mood_summary.dart';
import 'package:vibzcheck/features/session/domain/queue_track.dart';
import 'package:vibzcheck/features/session/domain/track.dart';

QueueTrack _track({
  required String id,
  required List<String> moodTags,
  int voteScore = 0,
  bool played = false,
}) {
  return QueueTrack(
    id: id,
    sourceId: id,
    source: TrackSource.mock,
    title: id,
    artist: 'a',
    album: 'b',
    durationMs: 180000,
    addedBy: 'u1',
    addedByName: 'Alice',
    voteScore: voteScore,
    moodTags: moodTags,
    played: played,
  );
}

void main() {
  test('empty queue returns null', () {
    expect(computeMoodSummary(const []), isNull);
  });

  test('queue with no tagged tracks returns null', () {
    final summary = computeMoodSummary([
      _track(id: 't1', moodTags: const []),
    ]);
    expect(summary, isNull);
  });

  test('single tagged track picks that mood', () {
    final summary = computeMoodSummary([
      _track(id: 't1', moodTags: const ['chill']),
    ]);
    expect(summary?.top, 'chill');
  });

  test('upvotes boost a mood above a non-upvoted one', () {
    final summary = computeMoodSummary([
      _track(id: 't1', moodTags: const ['chill']),
      _track(id: 't2', moodTags: const ['hype'], voteScore: 5),
    ]);
    expect(summary?.top, 'hype');
  });

  test('downvoted tracks do not contribute to mood', () {
    final summary = computeMoodSummary([
      _track(id: 't1', moodTags: const ['moody'], voteScore: -2),
      _track(id: 't2', moodTags: const ['chill']),
    ]);
    expect(summary?.top, 'chill');
    expect(summary?.scores.containsKey('moody'), isFalse);
  });

  test('played tracks contribute at reduced weight', () {
    final summary = computeMoodSummary([
      _track(id: 't1', moodTags: const ['chill'], played: true),
      _track(id: 't2', moodTags: const ['hype']),
    ]);
    expect(summary?.top, 'hype');
    expect(summary!.scores['chill']! < summary.scores['hype']!, isTrue);
  });

  test('tag casing and whitespace are normalised', () {
    final summary = computeMoodSummary([
      _track(id: 't1', moodTags: const [' Chill ']),
      _track(id: 't2', moodTags: const ['CHILL']),
    ]);
    expect(summary?.top, 'chill');
    expect(summary!.scores.keys, contains('chill'));
  });
}
