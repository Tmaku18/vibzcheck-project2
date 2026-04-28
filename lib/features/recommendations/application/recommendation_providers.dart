import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../session/application/session_providers.dart';
import '../../session/data/track_search_repository.dart';
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
final sessionSuggestionsProvider =
    FutureProvider.family<List<Suggestion>, String>((ref, sessionId) async {
  final queueAsync = ref.watch(sessionQueueProvider(sessionId));
  final queue = queueAsync.value ?? const [];
  // We need a catalogue to pick from. Empty query returns the whole mock
  // catalogue; once Spotify is wired the Cloud Function will return a mood-
  // biased candidate set instead.
  final catalogue =
      await ref.read(trackSearchRepositoryProvider).search('');
  return ref
      .read(trackRecommenderProvider)
      .recommendNext(queue: queue, catalogue: catalogue);
});

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
