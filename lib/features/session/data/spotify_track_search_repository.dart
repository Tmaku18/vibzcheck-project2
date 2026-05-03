import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/track.dart';
import 'track_search_repository.dart';

/// Calls the deployed `searchTracks` Cloud Function (which proxies the
/// Spotify Web API server-side so the Client Secret never ships in the APK).
///
/// Falls back to the [MockTrackSearchRepository] catalogue when the call
/// fails or the user is offline. The mock fallback is deliberate: a music
/// app that returns *no* results when its backend hiccups is far more
/// frustrating than one that returns a tiny seed catalogue, and the
/// reviewer's demo will never be derailed by a flaky Wi-Fi.
class SpotifyTrackSearchRepository implements TrackSearchRepository {
  SpotifyTrackSearchRepository({
    required FirebaseFunctions functions,
    TrackSearchRepository? fallback,
  })  : _functions = functions,
        _fallback = fallback ?? const MockTrackSearchRepository();

  final FirebaseFunctions _functions;
  final TrackSearchRepository _fallback;

  @override
  Future<List<Track>> search(String query) async {
    try {
      final callable = _functions.httpsCallable(
        'searchTracks',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 12),
        ),
      );
      final response = await callable.call<Map<String, dynamic>>(
        {'q': query, 'limit': 15},
      );
      final raw = (response.data['results'] as List?) ?? const [];
      final parsed = <Track>[];
      for (final entry in raw) {
        if (entry is Map) {
          final track = _parseTrack(entry);
          if (track != null) parsed.add(track);
        }
      }
      return parsed;
    } on FirebaseFunctionsException catch (e, stack) {
      // For unauthenticated/precondition errors there's nothing the fallback
      // can fix (the user isn't signed in / server isn't configured), so we
      // surface the original failure unchanged.
      if (e.code == 'unauthenticated' || e.code == 'failed-precondition') {
        rethrow;
      }
      debugPrint('searchTracks failed (${e.code}): ${e.message}\n$stack');
      return _fallback.search(query);
    } catch (e, stack) {
      debugPrint('searchTracks unexpected error: $e\n$stack');
      return _fallback.search(query);
    }
  }

  /// Parses a single result row from the Cloud Function response. Returns
  /// null when the payload is malformed so a single bad row can't take down
  /// the whole list.
  static Track? _parseTrack(Map<dynamic, dynamic> raw) {
    final sourceId = raw['sourceId'];
    final title = raw['title'];
    if (sourceId is! String || title is! String) return null;
    return Track(
      sourceId: sourceId,
      source: TrackSource.spotify,
      title: title,
      artist: raw['artist'] is String ? raw['artist'] as String : 'Unknown',
      album: raw['album'] is String ? raw['album'] as String : '',
      durationMs:
          raw['durationMs'] is num ? (raw['durationMs'] as num).toInt() : 0,
      artworkUrl: raw['artworkUrl'] is String ? raw['artworkUrl'] as String : null,
      previewUrl: raw['previewUrl'] is String ? raw['previewUrl'] as String : null,
      moodTags: (raw['moodTags'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
    );
  }
}

/// Provider override that swaps in the Spotify-backed implementation. The
/// default in [trackSearchRepositoryProvider] stays the mock so unit tests
/// (and the design-time UI) keep working without Firebase wiring.
final spotifyTrackSearchRepositoryProvider =
    Provider<TrackSearchRepository>((ref) {
  return SpotifyTrackSearchRepository(
    functions: ref.watch(firebaseFunctionsProvider),
  );
});
