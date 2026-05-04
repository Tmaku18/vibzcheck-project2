/**
 * Vibzcheck Cloud Functions.
 *
 * Currently exports a single callable, `searchTracks`, that brokers
 * Spotify Web API calls so the Spotify Client Secret never ships in the
 * Android APK. This is the standard "Client Credentials Flow" that
 * Spotify documents for app-only catalogue access.
 *
 *   Flow per call:
 *     1. The Flutter app calls `httpsCallable('searchTracks')` with `{ q }`.
 *     2. This function ensures it has a non-expired bearer token (cached
 *        in module scope so warm invocations skip the round trip).
 *     3. It hits `https://api.spotify.com/v1/search?q=...&type=track`.
 *     4. It maps each Spotify track into Vibzcheck's lean `Track` shape
 *        plus a list of rule-based `moodTags` derived from the album /
 *        artist name (the recommender consumes those tags).
 */

import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";

const SPOTIFY_CLIENT_ID = defineSecret("SPOTIFY_CLIENT_ID");
const SPOTIFY_CLIENT_SECRET = defineSecret("SPOTIFY_CLIENT_SECRET");

const SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token";
const SPOTIFY_SEARCH_URL = "https://api.spotify.com/v1/search";

// In-memory token cache survives within a warm function instance, which is
// the common case for Vibzcheck's intermittent traffic. Cold starts will
// re-fetch the token, which is cheap (one HTTPS call to Spotify).
let cachedToken: {value: string; expiresAt: number} | null = null;

interface SpotifyTokenResponse {
  access_token: string;
  expires_in: number;
}

interface SpotifyImage {
  url: string;
  width?: number;
  height?: number;
}

interface SpotifyArtist {
  name: string;
}

interface SpotifyAlbum {
  name: string;
  images: SpotifyImage[];
}

interface SpotifyTrack {
  id: string;
  name: string;
  artists: SpotifyArtist[];
  album: SpotifyAlbum;
  duration_ms: number;
  preview_url: string | null;
  explicit: boolean;
}

interface SpotifySearchResponse {
  tracks?: {
    items: SpotifyTrack[];
  };
}

interface VibzcheckTrack {
  sourceId: string;
  source: "spotify";
  title: string;
  artist: string;
  album: string;
  durationMs: number;
  artworkUrl: string | null;
  previewUrl: string | null;
  moodTags: string[];
  explicit: boolean;
}

/**
 * Fetches a fresh Spotify bearer token unless the cached one has at least
 * 30 seconds of life left. We never persist the token outside this
 * function's process memory — Spotify rotates client_secret values
 * server-side, so persistence isn't worth the risk.
 */
async function getSpotifyAccessToken(
  clientId: string,
  clientSecret: string,
): Promise<string> {
  const now = Date.now();
  if (cachedToken && cachedToken.expiresAt > now + 30_000) {
    return cachedToken.value;
  }

  // Defensive trim: PowerShell's pipe and several other shells silently
  // append CR/LF when piping into `firebase functions:secrets:set`, which
  // Spotify rejects with `invalid_client`. Trimming here means the function
  // is robust against an accidentally-newline-terminated secret value.
  const cleanId = clientId.trim();
  const cleanSecret = clientSecret.trim();

  const credentials = Buffer.from(`${cleanId}:${cleanSecret}`).toString(
    "base64",
  );

  const response = await fetch(SPOTIFY_TOKEN_URL, {
    method: "POST",
    headers: {
      Authorization: `Basic ${credentials}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });

  if (!response.ok) {
    const text = await response.text();
    logger.error("Spotify token request failed", {
      status: response.status,
      body: text,
    });
    throw new HttpsError(
      "unavailable",
      "Could not obtain a Spotify access token.",
    );
  }

  const data = (await response.json()) as SpotifyTokenResponse;
  cachedToken = {
    value: data.access_token,
    expiresAt: now + data.expires_in * 1000,
  };
  return data.access_token;
}

/**
 * Heuristic mood tagger so the rule-based recommender on the client has
 * something useful to consume even though Spotify's audio-features API is
 * deprecated for new app credentials. The tags are deliberately broad so
 * recommendations stay defensible.
 */
function deriveMoodTags(track: SpotifyTrack): string[] {
  const haystack = `${track.name} ${track.album.name} ${track.artists
    .map((a) => a.name)
    .join(" ")}`.toLowerCase();
  const tags = new Set<string>();

  const rules: Array<[RegExp, string]> = [
    [/\b(love|romance|heart|kiss)\b/, "romance"],
    [/\b(party|dance|club|tonight|fiesta)\b/, "dance"],
    [/\b(remix|edit|version|extended)\b/, "remix"],
    [/\b(sad|tears|alone|lonely|cry)\b/, "melancholy"],
    [/\b(sun|summer|beach|sky|ocean)\b/, "feelgood"],
    [/\b(rap|hip[- ]?hop|trap|drill)\b/, "rap"],
    [/\b(rock|metal|punk|grunge)\b/, "rock"],
    [/\b(country|cowboy|nashville)\b/, "country"],
    [/\b(jazz|swing|blues|soul)\b/, "soul"],
    [/\b(synth|wave|electro|future)\b/, "synth"],
    [/\b(chill|lofi|relax|sleep)\b/, "chill"],
    [/\b(hype|fire|hot|loud|wild)\b/, "hype"],
  ];

  for (const [pattern, tag] of rules) {
    if (pattern.test(haystack)) tags.add(tag);
  }

  if (track.duration_ms < 150_000) tags.add("short");
  if (track.duration_ms > 300_000) tags.add("epic");
  if (track.explicit) tags.add("explicit");

  if (tags.size === 0) tags.add("pop");
  return Array.from(tags);
}

function pickArtwork(album: SpotifyAlbum): string | null {
  if (album.images.length === 0) return null;
  const sorted = [...album.images].sort(
    (a, b) => (a.width ?? 0) - (b.width ?? 0),
  );
  // Prefer the smallest image >= 200px on the long side, otherwise largest.
  const mid = sorted.find((img) => (img.width ?? 0) >= 200);
  return (mid ?? sorted[sorted.length - 1]).url;
}

function toVibzcheckTrack(track: SpotifyTrack): VibzcheckTrack {
  return {
    sourceId: track.id,
    source: "spotify",
    title: track.name,
    artist: track.artists.map((a) => a.name).join(", "),
    album: track.album.name,
    durationMs: track.duration_ms,
    artworkUrl: pickArtwork(track.album),
    previewUrl: track.preview_url,
    moodTags: deriveMoodTags(track),
    explicit: track.explicit,
  };
}

/**
 * Callable: searchTracks
 *
 * Request:  { q: string, limit?: number (1..20, default 15) }
 * Response: { results: VibzcheckTrack[] }
 *
 * Auth:     Requires a signed-in Firebase user. Vibzcheck members can only
 *           queue tracks while in a session, so anonymous catalogue access
 *           offers no value and just inflates Spotify quota.
 */
export const searchTracks = onCall(
  {
    region: "us-central1",
    secrets: [SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET],
    enforceAppCheck: false,
    timeoutSeconds: 15,
    memory: "256MiB",
    // Gen 2 callables run on Cloud Run, which by default rejects all
    // unauthenticated traffic at the IAM layer. We need `public` so the
    // request reaches our handler, where the Firebase callable middleware
    // then validates the user's ID token and populates `request.auth`.
    invoker: "public",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in before searching tracks.",
      );
    }

    const data = request.data as {q?: unknown; limit?: unknown};
    const rawQuery = typeof data.q === "string" ? data.q.trim() : "";
    if (rawQuery.length === 0) {
      return {results: []};
    }
    if (rawQuery.length > 80) {
      throw new HttpsError(
        "invalid-argument",
        "Search query is too long (max 80 characters).",
      );
    }
    // Spotify's /v1/search currently rejects `limit > 10` for the
    // client-credentials scope on free Spotify Developer apps with a
    // confusing `400 "Invalid limit"` error, even though their public
    // docs still say 50. We cap server-side at 10 so any client request
    // (legacy clients sending 15, manual curl tests, etc.) still works.
    const limitInput =
      typeof data.limit === "number" ? Math.floor(data.limit) : 10;
    const limit = Math.min(10, Math.max(1, limitInput));

    const clientId = SPOTIFY_CLIENT_ID.value();
    const clientSecret = SPOTIFY_CLIENT_SECRET.value();
    if (!clientId || !clientSecret) {
      throw new HttpsError(
        "failed-precondition",
        "Spotify credentials are not configured on the server.",
      );
    }

    const token = await getSpotifyAccessToken(clientId, clientSecret);

    const url = new URL(SPOTIFY_SEARCH_URL);
    url.searchParams.set("q", rawQuery);
    url.searchParams.set("type", "track");
    url.searchParams.set("limit", String(limit));
    url.searchParams.set("market", "US");

    const response = await fetch(url.toString(), {
      headers: {Authorization: `Bearer ${token}`},
    });

    if (response.status === 401) {
      // Token may have been revoked between cache hits; clear and retry once.
      cachedToken = null;
      const retryToken = await getSpotifyAccessToken(clientId, clientSecret);
      const retryResponse = await fetch(url.toString(), {
        headers: {Authorization: `Bearer ${retryToken}`},
      });
      if (!retryResponse.ok) {
        const body = await retryResponse.text();
        logger.error("Spotify search retry failed", {
          status: retryResponse.status,
          body,
        });
        throw new HttpsError(
          "unavailable",
          "Spotify search is temporarily unavailable.",
        );
      }
      const retryData =
        (await retryResponse.json()) as SpotifySearchResponse;
      const items = retryData.tracks?.items ?? [];
      return {results: items.map(toVibzcheckTrack)};
    }

    if (!response.ok) {
      const body = await response.text();
      logger.error("Spotify search failed", {
        status: response.status,
        body,
      });
      throw new HttpsError(
        "unavailable",
        "Spotify search is temporarily unavailable.",
      );
    }

    const responseBody = (await response.json()) as SpotifySearchResponse;
    const items = responseBody.tracks?.items ?? [];
    return {results: items.map(toVibzcheckTrack)};
  },
);
