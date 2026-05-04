# Vibzcheck — Bug Log

A concise diary of the harder bugs hit while building Vibzcheck end-to-end.
Each entry follows the four-part format the project plan asks for: **Issue,
Root cause, Fix, Affected files** — plus the commit that landed the fix so it
can be inspected in `git log`.

---

## Bug 1 — Voting twice did not zero the score

- **Issue.** Re-tapping the upvote arrow on a queued track toggled the vote
  off in the UI but `voteScore` remained `1` in Firestore. A unit test
  (`upvoting twice toggles the vote off`) caught it before it shipped.
- **Root cause.** `QueueRepository.castVote` cleared the user's vote by
  writing `votes[uid] = null`. `FakeFirebaseFirestore` happily accepts a
  `null` map value, but the real Firestore rejects it inside transactions —
  and even when it doesn't reject, a `null` entry still counts as a present
  key, so the recomputed denormalised score stayed wrong.
- **Fix.** Use `FieldValue.delete()` with a dotted-path update
  (`updates['votes.$uid'] = FieldValue.delete()`) so the per-user key is
  removed atomically inside the same transaction that recomputes
  `voteScore` / `upvotes` / `downvotes`.
- **Affected files.** `lib/features/session/data/queue_repository.dart`,
  `test/features/session/queue_repository_test.dart`.
- **Commit.** see history; landed during Phase 2 hardening (queue tests).

---

## Bug 2 — Joining by code was permission-denied

- **Issue.** Device B could not join a session created on Device A. The app
  displayed `Failed to join session` and the Firebase console showed a
  permission-denied write on `sessions/{id}`.
- **Root cause.** Classic chicken-and-egg in the security rules. To join, a
  user had to read the `sessions` doc to find one with their code. But the
  `read` rule required them to already be a member. Non-members literally
  could not see any session, so no `where('code', '==', code)` query
  succeeded.
- **Fix.** Two-part change:
  1.  Introduced a public `joinCodes/{code}` collection mapping
      code → `{sessionId, ownerId}` that any signed-in user can read.
  2.  Added `isJoiningSelf()` to `firestore.rules` allowing a non-member to
      `update` a session **only** to add their own UID to `memberIds` and
      bump `memberCount` / `updatedAt` (a strict `affectedKeys().hasOnly`
      whitelist). `SessionRepository.joinByCode` was rewritten to look up
      the mapping first, then `arrayUnion` themselves into the session in a
      transaction without ever needing a session read.
- **Affected files.** `firestore.rules`,
  `lib/features/session/data/session_repository.dart`.
- **Commits.** `2ef6f86` (rules), `6c172de` (repository).

---

## Bug 3 — Home-screen session list spun forever

- **Issue.** After the join-by-code fix the home screen never resolved its
  loading spinner for either device. `flutter logs` showed
  `FAILED_PRECONDITION: The query requires an index`.
- **Root cause.** `watchSessionsForUser` runs
  `where('memberIds', arrayContains: uid).orderBy('updatedAt', desc: true)`.
  Composite indexes can only be deployed via `firestore.indexes.json` (or
  the console's auto-create link), and the new query had no matching index.
- **Fix.** Added a composite index for the `sessions` collection group:
  `(memberIds: CONTAINS, updatedAt: DESCENDING)`.
- **Affected files.** `firestore.indexes.json`.
- **Commit.** `b4694e4`.

---

## Bug 4 — Adding a track did not show up in the queue list

- **Issue.** Pushing **Add to queue** updated the queue *count* badge to 1
  but the track tile rendered as blank space. Logcat had a familiar
  `FAILED_PRECONDITION: The query requires an index` for the queue stream.
- **Root cause.** The queue listener was upgraded in Phase 3 to filter out
  played tracks (`played == false`) before sorting by `voteScore desc,
  addedAt asc`. The original index covered only the sort keys, not the
  equality filter, so the new query was rejected.
- **Fix.** Added a second composite index for the `queue` collection group:
  `(played: ASCENDING, voteScore: DESCENDING, addedAt: ASCENDING)`.
- **Affected files.** `firestore.indexes.json`.
- **Commit.** `4c797b2`.

---

## Bug 5 — `searchTracks` returned `invalid_client` from Spotify

- **Issue.** The deployed Cloud Function was returning `unavailable: Spotify
  search is temporarily unavailable.` to the Flutter client. The function
  logs showed Spotify rejecting the **token** request with
  `400 invalid_client`, even though the same Client ID + Secret worked from
  `curl` outside the function.
- **Root cause.** `firebase functions:secrets:set` had been fed the values
  via PowerShell pipes. PowerShell appended `\r\n` to each piped string, so
  the values stored in Google Secret Manager looked like
  `a08…3\r\nfd1…7` — the trailing CR/LF made the `Basic` header that
  Spotify decodes one byte too long, which it reports as `invalid_client`.
- **Fix.** Two layers, defence in depth:
  1.  Re-pushed both secrets using `WriteAllBytes` so no terminator could
      sneak in.
  2.  Added `clientId.trim()` / `clientSecret.trim()` calls inside
      `searchTracks` so a future shell quirk can't silently break the
      function again.
- **Affected files.** `functions/src/index.ts`,
  Google Secret Manager (`SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`
  versions bumped to v2).
- **Commit.** `f809f25`.

---

## Bug 6 — Spotify silently rejected `limit > 10`

- **Issue.** Once the credentials bug was fixed, search still returned an
  empty list in the app. Function logs showed `400 "Invalid limit"` from
  Spotify.
- **Root cause.** The Flutter client was asking for `limit: 15`. Spotify's
  public docs say `/v1/search` accepts `limit` up to `50`, but the
  Client-Credentials scope on a free Developer app currently rejects
  anything above `10` with a misleading `400 Invalid limit`. PowerShell
  probes confirmed `limit=10 OK`, `limit=11 → 400`.
- **Fix.** Capped server-side at `Math.min(10, …)` inside `searchTracks`
  (defence in depth — handles legacy clients and curl tests too) and
  lowered the Flutter request payload from `15` to `10`.
- **Affected files.** `functions/src/index.ts`,
  `lib/features/session/data/spotify_track_search_repository.dart`.
- **Commit.** `c63e537`.

---

## Reflection

The recurring pattern across bugs 2 → 4 → 5 → 6 was that **the failure
surface was inside Firebase / Spotify infrastructure, not inside our Dart
code**. Each one was caught quickly because the app was instrumented with:

- Realtime `flutter logs` / `adb logcat` running in a side terminal during
  every multi-device test.
- `firebase functions:log --lines 5` poll after every Cloud Function
  request.
- A small set of high-leverage automated tests
  (`queue_repository_test`, `spotify_track_search_repository_test`,
  `session_repository_test`) that pinned the contracts the manual tests
  could only sample.

The single biggest takeaway: when a request leaves the device, treat the
hop as opaque and start by inspecting the *server's* logs, not the
*client's*.
