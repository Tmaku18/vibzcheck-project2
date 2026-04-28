import '../../session/domain/queue_track.dart';
import '../../session/domain/track.dart';
import '../domain/suggestion.dart';

/// Rule-based "pick the next 3 songs" helper — the required AI challenge for
/// the Vibzcheck project.
///
/// The recommender is intentionally **transparent and deterministic**:
/// every score component is a labelled [SuggestionFactor] so the UI can
/// explain the picks to the room. No embeddings, no LLM call, no black box.
///
/// Scoring rules (each adds a factor):
///   1. **Mood match**: candidate tag in the session's top mood (+2.0).
///   2. **Overlap with upvoted queue tracks' tags**: +0.6 per shared tag.
///   3. **Novelty**: candidate not already in the queue (+0.5) or disqualified.
///   4. **Variety boost**: +0.4 when the candidate introduces a mood tag
///      that is currently under-represented (< 20% of queue tags).
///   5. **Stale-queue boost**: if the queue top track has been played already
///      or has score <= 0, prefer any non-queued candidate (+0.3).
class TrackRecommender {
  const TrackRecommender();

  List<Suggestion> recommendNext({
    required List<QueueTrack> queue,
    required List<Track> catalogue,
    int topK = 3,
  }) {
    if (catalogue.isEmpty) return const [];

    final queuedKeys = queue
        .map((q) => '${q.source.asString}_${q.sourceId}')
        .toSet();
    final upvotedTags = <String>{};
    final tagFrequency = <String, int>{};
    var totalQueueTags = 0;
    for (final q in queue) {
      for (final tag in q.moodTags) {
        final clean = tag.toLowerCase();
        tagFrequency[clean] = (tagFrequency[clean] ?? 0) + 1;
        totalQueueTags += 1;
        if (q.voteScore > 0) upvotedTags.add(clean);
      }
    }

    final topMood = _dominantTag(tagFrequency);
    final queueLooksStale = queue.isEmpty ||
        queue.every((q) => q.played || q.voteScore <= 0);

    final candidates = <Suggestion>[];
    for (final track in catalogue) {
      final key = '${track.source.asString}_${track.sourceId}';
      final factors = <SuggestionFactor>[];

      if (queuedKeys.contains(key)) {
        // Hard skip: don't recommend something that's already in the queue.
        continue;
      }
      factors.add(const SuggestionFactor(
        label: 'Not yet in the queue',
        weight: 0.5,
      ));

      final candidateTags =
          track.moodTags.map((t) => t.toLowerCase()).toSet();

      if (topMood != null && candidateTags.contains(topMood)) {
        factors.add(SuggestionFactor(
          label: 'Matches room mood (#$topMood)',
          weight: 2.0,
        ));
      }

      final overlapTags = candidateTags.intersection(upvotedTags);
      if (overlapTags.isNotEmpty) {
        factors.add(SuggestionFactor(
          label: 'Shares mood tags with upvoted tracks '
              '(${overlapTags.join(', ')})',
          weight: 0.6 * overlapTags.length,
        ));
      }

      if (totalQueueTags > 0) {
        for (final tag in candidateTags) {
          final freq = tagFrequency[tag] ?? 0;
          final share = freq / totalQueueTags;
          if (share < 0.2) {
            factors.add(SuggestionFactor(
              label: 'Adds variety (#$tag under-represented)',
              weight: 0.4,
            ));
            break;
          }
        }
      }

      if (queueLooksStale) {
        factors.add(const SuggestionFactor(
          label: 'Queue has gone flat — fresh energy',
          weight: 0.3,
        ));
      }

      final score = factors.fold<double>(0, (acc, f) => acc + f.weight);
      candidates.add(
        Suggestion(track: track, score: score, factors: factors),
      );
    }

    candidates.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      // Deterministic tie-break by source id so test runs are stable.
      return a.track.sourceId.compareTo(b.track.sourceId);
    });
    return candidates.take(topK).toList();
  }

  String? _dominantTag(Map<String, int> frequency) {
    if (frequency.isEmpty) return null;
    return frequency.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }
}
