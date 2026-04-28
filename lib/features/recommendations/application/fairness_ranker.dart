import '../../session/domain/queue_track.dart';
import '../domain/suggestion.dart';

/// A queue track re-ranked by the fairness module, paired with the factors
/// that moved its position. Surfaced to the UI so the host can explain
/// "why is *this* track next and not the one with the highest vote score?"
class RankedTrack {
  const RankedTrack({
    required this.track,
    required this.score,
    required this.factors,
  });

  final QueueTrack track;
  final double score;
  final List<SuggestionFactor> factors;
}

/// Graduate-level challenge: re-orders the session queue so the ordering
/// balances **popularity (votes)**, **fairness (member participation)**, and
/// **recency**, and *explains every move*.
///
/// Why this is graduate-level rather than just "sort by voteScore":
///
///   * A pure `voteScore desc` ordering lets popular members dominate the
///     session (their tracks get more votes simply because more people know
///     them). A fairness weight boosts tracks from members who have added
///     fewer tracks to balance airtime.
///   * Recency prevents the same track from sitting at the top forever: once
///     a track has been in the queue a long time, its score decays slightly.
///   * Every factor is labelled + exposed so the output is defensible.
///
/// Scoring:
///   * Base score  = `voteScore` (as a double).
///   * Fairness    = `+fairnessWeight * (1 - memberShare)`, where
///                   `memberShare = (tracks added by this member) /
///                                  (total tracks in queue)`.
///   * Recency     = `+recencyWeight * freshness`, where freshness ranges
///                   from 1.0 (just added) to 0.0 (`staleAfter` old or more).
///   * Heard-tax   = `-1.0` if the track has already played.
class FairnessRanker {
  const FairnessRanker({
    this.fairnessWeight = 1.5,
    this.recencyWeight = 0.75,
    this.staleAfter = const Duration(minutes: 30),
    this.nowBuilder,
  });

  final double fairnessWeight;
  final double recencyWeight;
  final Duration staleAfter;
  final DateTime Function()? nowBuilder;

  List<RankedTrack> rank(List<QueueTrack> queue) {
    if (queue.isEmpty) return const [];
    final now = (nowBuilder ?? DateTime.now)();

    final totalTracks = queue.length;
    final perMemberTracks = <String, int>{};
    for (final q in queue) {
      perMemberTracks[q.addedBy] = (perMemberTracks[q.addedBy] ?? 0) + 1;
    }

    final ranked = <RankedTrack>[];
    for (final q in queue) {
      final factors = <SuggestionFactor>[];

      // Popularity from votes.
      factors.add(SuggestionFactor(
        label: q.voteScore == 0
            ? 'No votes yet'
            : 'Vote score ${q.voteScore >= 0 ? '+' : ''}${q.voteScore}',
        weight: q.voteScore.toDouble(),
      ));

      // Fairness based on member participation.
      final memberTracks = perMemberTracks[q.addedBy] ?? 1;
      final memberShare = memberTracks / totalTracks;
      final fairnessBoost = fairnessWeight * (1 - memberShare);
      if (fairnessBoost > 0) {
        factors.add(SuggestionFactor(
          label: 'Fairness boost for ${q.addedByName} '
              '(${(memberShare * 100).toStringAsFixed(0)}% of queue)',
          weight: double.parse(fairnessBoost.toStringAsFixed(2)),
        ));
      }

      // Recency: linear decay from 1.0 to 0.0 across `staleAfter`.
      if (q.addedAt != null) {
        final age = now.difference(q.addedAt!);
        final freshness =
            1.0 - (age.inMilliseconds / staleAfter.inMilliseconds);
        final clamped = freshness.clamp(0.0, 1.0);
        final recencyContribution = recencyWeight * clamped;
        if (recencyContribution > 0.01) {
          factors.add(SuggestionFactor(
            label: clamped > 0.75
                ? 'Fresh add (just queued)'
                : 'Still relatively fresh',
            weight: double.parse(recencyContribution.toStringAsFixed(2)),
          ));
        }
      }

      if (q.played) {
        factors.add(const SuggestionFactor(
          label: 'Already played — lowered to avoid repeats',
          weight: -1.0,
        ));
      }

      final score = factors.fold<double>(0, (acc, f) => acc + f.weight);
      ranked.add(RankedTrack(track: q, score: score, factors: factors));
    }

    ranked.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      // Tie-break: oldest addedAt wins (first-come-first-served).
      final aTime = a.track.addedAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.track.addedAt?.millisecondsSinceEpoch ?? 0;
      return aTime.compareTo(bTime);
    });
    return ranked;
  }
}
