import '../domain/queue_track.dart';

/// Derives a human-readable mood label for a session from the queue.
///
/// Kept as a pure function (no Firestore, no Riverpod) so it is trivial to
/// unit test and so the same logic can later be reused server-side from a
/// Cloud Function if we want to persist the summary.
///
/// Weighting rules:
///   * Tags on played tracks are worth 0.5 (influence decays).
///   * Tags on unplayed tracks are worth 1.0.
///   * Tags weighted by (1 + max(0, voteScore)) so upvoted moods dominate.
///   * Downvoted tracks (voteScore < 0) contribute 0 — the room rejected
///     the vibe, so the summary shouldn't claim it.
///
/// The returned string is `null` when the queue has no tagged tracks, which
/// lets the UI fall back to "Set the vibe".
class MoodSummary {
  const MoodSummary({required this.top, required this.scores});

  /// The mood with the highest weighted score.
  final String top;

  /// All mood tags mapped to their weighted contribution. Exposed so the UI
  /// (or tests) can show the reasoning behind the top pick.
  final Map<String, double> scores;

  @override
  String toString() => 'MoodSummary(top: $top, scores: $scores)';
}

MoodSummary? computeMoodSummary(Iterable<QueueTrack> tracks) {
  final scores = <String, double>{};
  for (final track in tracks) {
    final baseWeight = track.played ? 0.5 : 1.0;
    // A single downvoted track still counted against its own tags would
    // penalise the rest of the room unfairly, so we zero it out instead.
    if (track.voteScore < 0) continue;
    final weight = baseWeight * (1 + track.voteScore);
    for (final tag in track.moodTags) {
      final clean = tag.trim().toLowerCase();
      if (clean.isEmpty) continue;
      scores[clean] = (scores[clean] ?? 0) + weight;
    }
  }
  if (scores.isEmpty) return null;
  final top =
      scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return MoodSummary(top: top, scores: scores);
}
