import '../../session/domain/track.dart';

/// A single "reason" that contributed to a suggestion's score.
///
/// Keeping factors as first-class objects is what makes the recommender
/// **explainable** for the curated-questions defence: the UI can render the
/// same list the scorer used, so graders can see *why* a track was ranked
/// where it was.
class SuggestionFactor {
  const SuggestionFactor({
    required this.label,
    required this.weight,
  });

  final String label;
  final double weight;

  @override
  String toString() =>
      '$label (${weight >= 0 ? '+' : ''}${weight.toStringAsFixed(2)})';
}

/// The output of the rule-based next-song helper.
class Suggestion {
  const Suggestion({
    required this.track,
    required this.score,
    required this.factors,
  });

  final Track track;
  final double score;
  final List<SuggestionFactor> factors;

  /// Primary reason (largest positive factor) surfaced when we only have
  /// space for one line of explanation in the UI.
  String get primaryReason {
    if (factors.isEmpty) return 'Fresh pick';
    final top = factors.reduce((a, b) => a.weight >= b.weight ? a : b);
    return top.label;
  }
}
