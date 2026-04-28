import 'package:cloud_firestore/cloud_firestore.dart';

import 'track.dart';

/// A track in a session's shared queue, stored at
/// `sessions/{sessionId}/queue/{trackDocId}`.
///
/// Vote state lives inline on the document:
///   * [votes] - map of `{uid: +1}` or `{uid: -1}` so each user only ever has
///     one active vote on a track.
///   * [voteScore] - denormalised sum of [votes] values. Kept denormalised so
///     the queue can be ordered with a single `orderBy('voteScore', desc)`.
///   * [upvotes] / [downvotes] - denormalised counts for UI chips.
///
/// Writes to this document always happen inside a Firestore transaction (see
/// `QueueRepository.castVote`) so concurrent upvotes/downvotes cannot corrupt
/// the aggregates.
class QueueTrack {
  const QueueTrack({
    required this.id,
    required this.sourceId,
    required this.source,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.addedBy,
    required this.addedByName,
    this.artworkUrl,
    this.previewUrl,
    this.votes = const <String, int>{},
    this.voteScore = 0,
    this.upvotes = 0,
    this.downvotes = 0,
    this.moodTags = const <String>[],
    this.played = false,
    this.addedAt,
  });

  final String id;
  final String sourceId;
  final TrackSource source;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String? artworkUrl;
  final String? previewUrl;

  final String addedBy;
  final String addedByName;
  final DateTime? addedAt;

  final Map<String, int> votes;
  final int voteScore;
  final int upvotes;
  final int downvotes;
  final List<String> moodTags;
  final bool played;

  int voteOf(String uid) => votes[uid] ?? 0;

  String get durationLabel {
    final totalSeconds = (durationMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Payload written when a track is first added to the queue. The vote
  /// aggregates are initialised to zero here rather than relying on
  /// `FieldValue.increment` so every new doc has a deterministic shape.
  static Map<String, dynamic> creationPayload({
    required Track track,
    required String addedBy,
    required String addedByName,
  }) {
    return {
      'sourceId': track.sourceId,
      'source': track.source.asString,
      'title': track.title,
      'artist': track.artist,
      'album': track.album,
      'durationMs': track.durationMs,
      'artworkUrl': track.artworkUrl,
      'previewUrl': track.previewUrl,
      'moodTags': track.moodTags,
      'addedBy': addedBy,
      'addedByName': addedByName,
      'addedAt': FieldValue.serverTimestamp(),
      'votes': <String, int>{},
      'voteScore': 0,
      'upvotes': 0,
      'downvotes': 0,
      'played': false,
    };
  }

  factory QueueTrack.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final rawVotes = data['votes'];
    final votes = <String, int>{};
    if (rawVotes is Map) {
      rawVotes.forEach((k, v) {
        if (k is String && v is num) votes[k] = v.toInt();
      });
    }
    return QueueTrack(
      id: snapshot.id,
      sourceId: (data['sourceId'] as String?) ?? snapshot.id,
      source: TrackSourceX.parse(data['source'] as String?),
      title: (data['title'] as String?) ?? 'Unknown title',
      artist: (data['artist'] as String?) ?? 'Unknown artist',
      album: (data['album'] as String?) ?? '',
      durationMs: (data['durationMs'] as num?)?.toInt() ?? 0,
      artworkUrl: data['artworkUrl'] as String?,
      previewUrl: data['previewUrl'] as String?,
      addedBy: (data['addedBy'] as String?) ?? '',
      addedByName: (data['addedByName'] as String?) ?? 'Someone',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
      votes: votes,
      voteScore: (data['voteScore'] as num?)?.toInt() ?? 0,
      upvotes: (data['upvotes'] as num?)?.toInt() ?? 0,
      downvotes: (data['downvotes'] as num?)?.toInt() ?? 0,
      moodTags:
          (data['moodTags'] as List?)?.whereType<String>().toList() ?? const [],
      played: (data['played'] as bool?) ?? false,
    );
  }
}
