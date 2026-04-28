/// Source of a track's metadata. Currently only `mock` during Phase 2
/// development; `spotify` will be added once the Cloud Function bridge ships.
enum TrackSource { spotify, mock }

extension TrackSourceX on TrackSource {
  String get asString => name;

  static TrackSource parse(String? raw) {
    return TrackSource.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => TrackSource.mock,
    );
  }
}

/// Catalogue-level track metadata returned from search. It is NOT stored in
/// Firestore directly — [QueueTrack] pulls the fields it needs when a track
/// is added to a session queue.
class Track {
  const Track({
    required this.sourceId,
    required this.source,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.artworkUrl,
    this.previewUrl,
    this.moodTags = const <String>[],
  });

  final String sourceId;
  final TrackSource source;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String? artworkUrl;
  final String? previewUrl;

  /// Rule-based mood tags (e.g. `chill`, `hype`) applied by the search
  /// repository. Used by the Phase 3 rule-based recommender.
  final List<String> moodTags;

  String get durationLabel {
    final totalSeconds = (durationMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
