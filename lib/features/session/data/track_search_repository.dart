import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/track.dart';

/// Abstract catalogue search so the UI never depends on a specific backend.
///
/// Phase 2 ships [MockTrackSearchRepository] so the end-to-end session /
/// queue / voting flow can be demoed without Spotify credentials. Phase 3
/// replaces the provider override with a Cloud-Functions-backed
/// `SpotifyTrackSearchRepository` without touching any UI code.
abstract class TrackSearchRepository {
  Future<List<Track>> search(String query);
}

/// Hard-coded catalogue used during Phase 2 development. The list is
/// deliberately small and varied so demos can show the filter, mood tags,
/// and UI artwork without a network round trip.
class MockTrackSearchRepository implements TrackSearchRepository {
  const MockTrackSearchRepository();

  static const _catalogue = <Track>[
    Track(
      sourceId: 'mock-blinding-lights',
      source: TrackSource.mock,
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      album: 'After Hours',
      durationMs: 200040,
      artworkUrl:
          'https://i.scdn.co/image/ab67616d0000b273ef017e899c0547a993a65cfc',
      moodTags: ['hype', 'synth'],
    ),
    Track(
      sourceId: 'mock-sunflower',
      source: TrackSource.mock,
      title: 'Sunflower',
      artist: 'Post Malone, Swae Lee',
      album: 'Spider-Man: Into the Spider-Verse',
      durationMs: 158040,
      artworkUrl:
          'https://i.scdn.co/image/ab67616d0000b273e2e352d89826aef6dbd5ff8f',
      moodTags: ['chill', 'feelgood'],
    ),
    Track(
      sourceId: 'mock-bad-guy',
      source: TrackSource.mock,
      title: 'bad guy',
      artist: 'Billie Eilish',
      album: 'WHEN WE ALL FALL ASLEEP, WHERE DO WE GO?',
      durationMs: 194087,
      artworkUrl:
          'https://i.scdn.co/image/ab67616d0000b27350a3147b4edd7701a876c6ce',
      moodTags: ['moody', 'dance'],
    ),
    Track(
      sourceId: 'mock-levitating',
      source: TrackSource.mock,
      title: 'Levitating',
      artist: 'Dua Lipa',
      album: 'Future Nostalgia',
      durationMs: 203064,
      artworkUrl:
          'https://i.scdn.co/image/ab67616d0000b2734bc66095f8a70bc4e6593f4f',
      moodTags: ['hype', 'dance'],
    ),
    Track(
      sourceId: 'mock-watermelon-sugar',
      source: TrackSource.mock,
      title: 'Watermelon Sugar',
      artist: 'Harry Styles',
      album: 'Fine Line',
      durationMs: 174000,
      artworkUrl:
          'https://i.scdn.co/image/ab67616d0000b27377fdcfda00db51b022ca3f33',
      moodTags: ['feelgood', 'summer'],
    ),
    Track(
      sourceId: 'mock-circles',
      source: TrackSource.mock,
      title: 'Circles',
      artist: 'Post Malone',
      album: "Hollywood's Bleeding",
      durationMs: 215280,
      artworkUrl:
          'https://i.scdn.co/image/ab67616d0000b273d5f3049d875f8ceb1f95374e',
      moodTags: ['chill', 'melancholy'],
    ),
    Track(
      sourceId: 'mock-stay',
      source: TrackSource.mock,
      title: 'STAY (with Justin Bieber)',
      artist: 'The Kid LAROI, Justin Bieber',
      album: 'F*CK LOVE 3: OVER YOU',
      durationMs: 141806,
      artworkUrl:
          'https://i.scdn.co/image/ab67616d0000b2738e6551a2944764bc8e33a960',
      moodTags: ['hype', 'pop'],
    ),
    Track(
      sourceId: 'mock-heat-waves',
      source: TrackSource.mock,
      title: 'Heat Waves',
      artist: 'Glass Animals',
      album: 'Dreamland',
      durationMs: 238805,
      artworkUrl:
          'https://i.scdn.co/image/ab67616d0000b2739e495fb707973f3390850eea',
      moodTags: ['chill', 'melancholy'],
    ),
    Track(
      sourceId: 'mock-as-it-was',
      source: TrackSource.mock,
      title: 'As It Was',
      artist: 'Harry Styles',
      album: "Harry's House",
      durationMs: 167303,
      artworkUrl:
          'https://i.scdn.co/image/ab67616d0000b2732e8ed79e177ff6011076f5f0',
      moodTags: ['feelgood', 'synth'],
    ),
    Track(
      sourceId: 'mock-industry-baby',
      source: TrackSource.mock,
      title: 'INDUSTRY BABY (feat. Jack Harlow)',
      artist: 'Lil Nas X, Jack Harlow',
      album: 'MONTERO',
      durationMs: 212000,
      artworkUrl:
          'https://i.scdn.co/image/ab67616d0000b2736f8bbb05d99ad5d43b3c4d39',
      moodTags: ['hype', 'rap'],
    ),
  ];

  @override
  Future<List<Track>> search(String query) async {
    final q = query.trim().toLowerCase();
    await Future.delayed(const Duration(milliseconds: 150));
    if (q.isEmpty) return _catalogue;
    return _catalogue.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q) ||
          t.moodTags.any((m) => m.toLowerCase().contains(q));
    }).toList();
  }
}

final trackSearchRepositoryProvider = Provider<TrackSearchRepository>((ref) {
  return const MockTrackSearchRepository();
});
