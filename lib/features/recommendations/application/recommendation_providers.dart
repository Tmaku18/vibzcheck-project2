import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../session/application/mood_summary.dart';
import '../../session/application/session_providers.dart';
import '../../session/data/track_search_repository.dart';
import '../../session/domain/queue_track.dart';
import '../domain/suggestion.dart';
import 'fairness_ranker.dart';
import 'track_recommender.dart';

final trackRecommenderProvider = Provider<TrackRecommender>((ref) {
  return const TrackRecommender();
});

final fairnessRankerProvider = Provider<FairnessRanker>((ref) {
  return const FairnessRanker();
});

/// Live-computed next-3 suggestions for a session. Recomputes whenever the
/// underlying queue stream emits (i.e. any vote, add, or remove).
///
/// The candidate pool is fetched by querying Spotify with a mood-biased
/// search term derived from the current queue (e.g. `chill playlist` when
/// the room mood is "chill"). A generic "top hits today" fallback is used
/// when the queue is empty so brand-new sessions still get suggestions.
final sessionSuggestionsProvider =
    FutureProvider.family<List<Suggestion>, String>((ref, sessionId) async {
  final queueAsync = ref.watch(sessionQueueProvider(sessionId));
  final queue = queueAsync.value ?? const <QueueTrack>[];
  final query = _seedQueryForQueue(queue);
  final catalogue =
      await ref.read(trackSearchRepositoryProvider).search(query);
  return ref
      .read(trackRecommenderProvider)
      .recommendNext(queue: queue, catalogue: catalogue);
});

/// Derives a Spotify search seed query from the current queue. Picks the
/// dominant mood tag if one exists, otherwise falls back to a generic
/// "top hits today" so brand-new sessions still get useful candidates.
String _seedQueryForQueue(List<QueueTrack> queue) {
  final mood = computeMoodSummary(queue)?.top;
  if (mood != null) return '$mood playlist';
  return 'top hits today';
}

/// Live fairness-ranked queue. The UI can toggle between this and the raw
/// vote-score ordering from [sessionQueueProvider].
final fairRankedQueueProvider = Provider.family<List<RankedTrack>, String>(
  (ref, sessionId) {
    final queueAsync = ref.watch(sessionQueueProvider(sessionId));
    final queue = queueAsync.value ?? const [];
    return ref.read(fairnessRankerProvider).rank(queue);
  },
);

/// UI toggle for "Fair ranking" vs "Vote ranking" on SessionScreen.
/// Defaults to vote ranking so vanilla Firestore ordering is still the
/// out-of-the-box experience; members can opt into fairness view per
/// session. Imported from `flutter_riverpod/legacy.dart` since Riverpod 3
/// moved StateProvider there rather than retiring it outright.
final fairRankingEnabledProvider =
    StateProvider.family<bool, String>((ref, sessionId) => false);
