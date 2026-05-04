# Vibzcheck — Curated Questions (Q&A with Code Evidence)

**Author.** Tanaka Makuvaza · CSC 6370 · CRN 13598 · GSU ID 002252191
**Project.** Vibzcheck — collaborative real-time listening sessions on
Flutter + Firebase.
**Repository.** [github.com/tanakamak/vibzcheck-project2](https://github.com/tanakamak/vibzcheck-project2)
**Track.** Solo, graduate (M.S.), 1-member team.

This document is **the answer key with full code references**. The
"questions-only" Word document required by the rubric is generated from
the section headings below (no answer text). I selected **14 questions**
following the official distribution: Implementation × 3, Architecture × 3,
Testing × 3, Firebase × 4, Reflection × 1.

---

## Implementation

### Q1. Feature Build Sequence — *Order of implementation and risk reduction*

The three most complex features were:
**(a)** real-time collaborative queue + voting,
**(b)** Spotify search through Firebase Cloud Functions, and
**(c)** the rule-based + fairness-ranking recommendations module.

I built them in that order because **each one validated the substrate
the next one assumed**:

1. **Queue + voting first** (commits in Phase 2). It exercised auth,
   Firestore, transactions, denormalised `voteScore`/`upvotes`/`downvotes`
   counters, and the security rules together. If any of those were
   broken, every later feature would inherit the same break. Tests in
   `test/features/session/queue_repository_test.dart` lock the contract.
2. **Spotify Cloud Function second** (commits `db6bc53` → `c01d0b2`).
   It introduced the *server-side* tier of the architecture
   (`functions/src/index.ts`). Doing it after voting meant the queue
   could already accept tracks from any source, so we could ship a
   `MockTrackSearchRepository` first and swap to `SpotifyTrackSearchRepository`
   without changing the queue UI. See
   `lib/features/session/data/track_search_repository.dart` and
   `lib/features/session/data/spotify_track_search_repository.dart`.
3. **Recommendations last** (commits `bd0fef9` → `446cc40`). Both
   `TrackRecommender` and `FairnessRanker` consume the queue and member
   data the first two features produce. Building them last meant they
   never had to be redesigned around schema changes.

This staircase shape is *de-risking*: each layer had a working,
tested predecessor before any new uncertainty was added on top.

**Evidence.** `git log --oneline | head -40` (full Phase 2 → Phase 3
sequence), `lib/features/session/data/queue_repository.dart`,
`functions/src/index.ts`, `lib/features/recommendations/`,
`submission/BUG_LOG.md` (entry 1).

---

### Q2. Feature Build Sequence — *Reworked feature after user-flow testing*

The **Add Track** screen was reworked after the first multi-emulator
test session. Originally it auto-ran an empty Spotify search on mount,
which wasted a Cloud Function invocation (and Spotify quota) every
time someone opened the screen and immediately backed out.

- **Before.** `_AddTrackScreenState.initState` called
  `_runSearch('')` unconditionally.
- **After.** The screen now starts in an explanatory empty state
  ("Type a song, artist, or album to search Spotify.") and only fires
  a search when the query field is non-empty. Mood-tag filter chips
  also gained a sticky "All" pseudo-tag so the chip row never appears
  empty.

**Evidence.**
`lib/features/session/presentation/add_track_screen.dart`, commit
`eb41ab7` (`feat(session): show explanatory empty-state on
AddTrackScreen instead of auto-empty-search`),
`submission/screenshots/CAPTURE_GUIDE.md` rows
`31_add_track_spotify_results.png` and `32_add_track_mood_filter.png`.

---

### Q3. State and Data Synchronization — *Real sync bug with safeguards*

**Bug.** Tapping "upvote" twice on a queue track left `voteScore = 1`
in Firestore even though the per-user tally cleared in the UI.

**Root cause.** The naive implementation cleared a vote with
`votes[uid] = null`. `FakeFirebaseFirestore` accepts that, but the
real Firestore preserves the `null` map entry, breaking the
denormalised score recompute that runs in the same transaction.

**Fix.** Use a dotted-path delete:

```dart
final updates = <String, Object?>{
  'voteScore': nextScore,
  'upvotes': nextUp,
  'downvotes': nextDown,
};
if (effectiveVote == 0) {
  updates['votes.$uid'] = FieldValue.delete();
} else {
  updates['votes.$uid'] = effectiveVote;
}
tx.update(trackRef, updates);
```

The whole flip happens inside a single Firestore transaction
(`runTransaction`) so two clients voting simultaneously can't
clobber each other's score, and the `upvoting twice toggles the vote
off` test in `test/features/session/queue_repository_test.dart`
prevents regression.

**Evidence.** `lib/features/session/data/queue_repository.dart`
(`castVote`), `test/features/session/queue_repository_test.dart`,
`submission/BUG_LOG.md` (entry 1).

---

## Architecture & Design

### Q4. Navigation and Screen Responsibility — *Decomposition of an over-large screen*

`SessionScreen` (`lib/features/session/presentation/session_screen.dart`)
became too large once chat, suggestions, and member roster all needed
to live together. I split it into **three composable sub-widgets** and
let the screen itself stay a tab host:

- `QueueTrackTile` (`presentation/widgets/queue_track_tile.dart`) —
  one row of the live queue, owns its vote button state.
- `SessionCard` (`presentation/widgets/session_card.dart`) — the
  reusable session summary used both on the home screen and inside
  the session header.
- `SuggestionsCard`
  (`features/recommendations/presentation/suggestions_card.dart`) —
  the AI helper, completely decoupled from the queue.

The screen's own `build` method is now mostly `TabBarView` plumbing
plus the queue list. State flows through Riverpod providers
(`session_providers.dart`, `chat_providers.dart`,
`recommendation_providers.dart`) so each tab re-fetches only what it
displays.

**Evidence.**
`lib/features/session/presentation/session_screen.dart`,
`lib/features/session/application/session_providers.dart`,
`lib/features/recommendations/application/recommendation_providers.dart`.

---

### Q5. Navigation and Screen Responsibility — *Maintainable navigation structure*

Navigation lives in a single declarative `GoRouter`
(`lib/app/router.dart`). Three properties make it scale:

- **Auth-aware redirects.** A `_RouterRefreshNotifier` adapts
  `FirebaseAuth.authStateChanges()` into a `Listenable` that
  `GoRouter` re-evaluates. Signed-out users hitting any private
  route get bounced to `/sign-in`; signed-in users hitting auth
  screens get sent home. Adding a new private route requires zero
  changes to the redirect logic.
- **Nested session routes.** The `/session/:sessionId` route owns
  child routes (`add-track`, `chat`) so a session ID stays in the
  URL even when navigating one level deeper. Adding a new
  per-session screen is a single `GoRoute` push under the parent.
- **Named routes.** All `context.goNamed('add-track', …)` calls use
  symbolic names instead of raw paths, so renaming the URL doesn't
  break callers.

**Evidence.** `lib/app/router.dart` (35 lines of declarative routing),
`lib/features/session/presentation/home_screen.dart` (named-route
push examples).

---

### Q6. Security and Data Decisions — *Rule that blocked a bad write*

The **`isJoiningSelf()`** rule in `firestore.rules` is the most
load-bearing security decision in the project:

```firestore
function isJoiningSelf() {
  return isSignedIn()
    && !(request.auth.uid in resource.data.memberIds)
    && request.auth.uid in request.resource.data.memberIds
    && request.resource.data.diff(resource.data).affectedKeys()
        .hasOnly(['memberIds', 'memberCount', 'updatedAt']);
}
```

**What it allows.** A *non-member* can update a session document
**only** to add their own UID to `memberIds` and bump the
denormalised counters that go with it.

**What it blocks.** A non-member trying to (a) add anyone *else's*
UID, (b) flip the session status, (c) overwrite the queue
listener's `currentTrackId`, or (d) change `ownerId` is rejected by
the `affectedKeys().hasOnly([...])` whitelist.

**Trade-off (from the same prompt's part 2).** I deliberately kept
the queue-vote per-field validation light during Phase 3 so I could
iterate the recommender quickly. Phase 4 hardening adds the per-
field vote rule (`request.resource.data.votes[request.auth.uid] in
[-1, 0, 1]`) once the recommender stopped changing the document
shape.

**Evidence.** `firestore.rules` (function + sessions/{sessionId}
update rule), commit `2ef6f86`, `submission/BUG_LOG.md` (entry 2).

---

## Testing & Reliability

### Q7. Failure Case Ownership — *Failure case the first implementation missed*

The original `SpotifyTrackSearchRepository` re-threw any
`FirebaseFunctionsException`, which meant a single Cloud Function
hiccup (cold start, Spotify rate limit, my own CRLF-in-secret bug —
see Bug 5 in the bug log) emptied the Add Track screen.

**Redesign.** The repo now *narrows* the rethrow set to errors the
fallback can't fix (`unauthenticated` and `failed-precondition`
mean the user is signed out or the server is misconfigured —
fallback would mask the real problem). Everything else, including
`unavailable`, returns the `MockTrackSearchRepository` catalogue so
the user still sees results:

```dart
} on FirebaseFunctionsException catch (e, stack) {
  if (e.code == 'unauthenticated' || e.code == 'failed-precondition') {
    rethrow;
  }
  debugPrint('searchTracks failed (${e.code}): ${e.message}\n$stack');
  return _fallback.search(query);
}
```

A music app that returns *zero* results when its backend hiccups is
much more frustrating to demo than one that returns a tiny
ten-track seed catalogue.

**Evidence.**
`lib/features/session/data/spotify_track_search_repository.dart`
(`search` method), `submission/BUG_LOG.md` entries 5 + 6.

---

### Q8. Failure Case Ownership — *UX redesign for lifecycle issue*

`AuthController.describeFirebaseAuthError` collapses every Firebase
error code into a single user-friendly line *and* deliberately
collapses `user-not-found`, `wrong-password`, and
`invalid-credential` into one shared "Email or password is
incorrect." line so attackers can't enumerate accounts.

The exhaustive mapping (and the safety property above) is pinned by
`test/features/auth/auth_error_messages_test.dart` so any future
change to the switch must ship with a paired test.

**Evidence.**
`lib/features/auth/application/auth_controller.dart`
(`describeFirebaseAuthError`),
`test/features/auth/auth_error_messages_test.dart` (11 cases),
`lib/features/auth/presentation/sign_in_screen.dart` (consumer).

---

### Q9. Performance Under Real Use — *Lag, profile, optimization*

**Symptom.** The home-screen sessions list spun forever for both
emulators after the join-by-code rewrite.

**Profiling.** `adb logcat | rg FAILED_PRECONDITION` immediately
showed the smoking gun:
`The query requires an index. You can create it here: https://...`

**Fix.** Composite index for the `sessions` collection group
covering `(memberIds: CONTAINS, updatedAt: DESCENDING)` —
declared in `firestore.indexes.json` (committed to source so the
infra is reproducible). The home query
(`watchSessionsForUser(uid)`) went from "stuck on splash" to
sub-200 ms first emission.

A near-identical bug recurred for the queue listener once Phase 3
added the `played == false` filter; the same playbook resolved it
(commit `4c797b2`).

**Evidence.** `firestore.indexes.json`,
`lib/features/session/data/session_repository.dart`
(`watchSessionsForUser`), `submission/BUG_LOG.md` entries 3 + 4.

---

## Firebase

### Q10. Firestore Data Modeling — *Hierarchy and subcollection rationale*

Top-level collections: `users`, `sessions`, `joinCodes`.
Subcollections under each session: `members`, `queue`, `messages`,
`suggestions`.

I picked **subcollections under sessions** instead of top-level
parallel collections (`queueTracks`, `chatMessages`, …) because:

- A single rule on `/sessions/{id}/queue/{trackId}` can call
  `isSessionMember(id)` once per request — top-level collections
  would have to repeat the membership lookup for every doc.
- Listener teardown is automatic when a user navigates out of the
  session screen (provider auto-dispose tears down all child
  streams).
- The `joinCodes/{code}` mapping stays top-level on purpose: it has
  to be readable by non-members so a non-member can resolve a code
  → sessionId before the membership rules apply (see Bug 2 in the
  bug log).

**Evidence.** `firestore.rules` (whole file shows the hierarchy),
`lib/features/session/data/session_repository.dart`,
`lib/features/session/data/queue_repository.dart`,
`lib/features/chat/data/chat_repository.dart`,
`submission/BUG_LOG.md` entry 2.

---

### Q11. Firestore Data Modeling — *Compound query that needed a composite index*

```dart
_sessions
    .where('memberIds', arrayContains: uid)
    .orderBy('updatedAt', descending: true)
    .snapshots()
```

This is the home screen's "sessions I'm in" query. It combines an
**`array-contains`** filter with an **`orderBy`** on a different
field, which Firestore requires a composite index for. Declared as:

```json
{
  "collectionGroup": "sessions",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "memberIds", "arrayConfig": "CONTAINS" },
    { "fieldPath": "updatedAt", "order": "DESCENDING" }
  ]
}
```

**Read-cost impact.** The index is *write-amplifying*: every
session update writes one extra index entry per member. For a
10-member session that's 10 index entries per `updatedAt` bump.
With Firestore's per-doc 1 KiB index limit and the default
`memberIds` cap I set at 50 in the join screen, each session stays
well under the 40 KiB index document budget. Reads are the same
single-query cost they would be without the index — the index just
makes the query *legal*.

**Evidence.** `firestore.indexes.json`,
`lib/features/session/data/session_repository.dart`
(`watchSessionsForUser`), commit `b4694e4`.

---

### Q12. Firebase Authentication & Security Rules — *Rule scoped to request.auth.uid*

```firestore
match /users/{uid} {
  allow read:   if isSelf(uid);
  allow create: if isSelf(uid);
  allow update: if isSelf(uid);
  allow delete: if false;
}

function isSelf(uid) {
  return isSignedIn() && request.auth.uid == uid;
}
```

A signed-in user can read or write **only** the document keyed by
their own UID. An unauthenticated request has `request.auth == null`
so `isSignedIn()` is `false` → access denied. A signed-in user
trying to read someone else's profile fails the `request.auth.uid
== uid` check → access denied.

**How it's tested.** Manually in the Firebase console **Rules
Playground** (see capture row `submission/screenshots/CAPTURE_GUIDE.md`
→ blocked-request screenshot slot) and indirectly in
`session_repository_test.dart` where the fake firestore allows the
same shape of writes our rules expect.

**Evidence.** `firestore.rules` (`/users/{uid}` block + `isSelf`),
`lib/features/auth/data/user_repository.dart` (consumer that always
keys on `currentUser.uid`).

---

### Q13. Firebase Cloud Messaging (FCM) — *Token lifecycle*

`FcmService` (`lib/features/notifications/fcm_service.dart`) owns
the full lifecycle:

1. **Permission.** `_messaging.requestPermission(...)` is called
   from `initForUser` once a real authenticated UID is known
   (driven by `authStateChangesProvider` listener in
   `lib/app/app.dart`).
2. **Token.** `_messaging.getToken()` produces the device token,
   stored at `users/{uid}.fcmTokens` (an array, so a single user
   with multiple devices accumulates tokens). See
   `UserRepository.addFcmToken`.
3. **Refresh.** `_tokenRefreshSubscription` listens to
   `_messaging.onTokenRefresh`; the new token replaces the old one
   in the same array via `arrayUnion` + `arrayRemove`.
4. **Foreground delivery.** `FirebaseMessaging.onMessage` pipes the
   payload into the active `ScaffoldMessengerState` as a SnackBar.
5. **Background / terminated delivery.** A top-level
   `vibzcheckFcmBackgroundHandler` registered *before* `runApp`
   in `lib/main.dart` satisfies the firebase_messaging contract
   that the platform uses a fresh isolate.
6. **Sign-out.** `dispose` cancels both subscriptions and removes
   the device token from `users/{uid}.fcmTokens` so a re-used
   device doesn't keep receiving the previous user's pushes.

**Evidence.** `lib/features/notifications/fcm_service.dart`,
`lib/main.dart` (background handler registration), `lib/app/app.dart`
(per-user init), `lib/features/auth/data/user_repository.dart`
(token persistence).

---

## Critical Reflection

### Q14. Team Engineering Reflection — *Early decision that created technical debt*

**Decision.** In Phase 2 the join-by-code flow was a single naive
Firestore query: `_sessions.where('code', '==', code).get()`,
followed by an `arrayUnion(uid)` write.

**The debt.** That query required **read access on the entire
`sessions` collection for every signed-in user**. The Phase 2
rules permitted it implicitly because we hadn't tightened them yet.
The first time we tightened reads to "members and owner only"
(which the rubric specifically rewards), join-by-code broke
end-to-end — the bug recorded in `submission/BUG_LOG.md` entry 2.

**Resolution.** Introduced a separate `joinCodes/{code}` mapping
collection that anyone signed-in can read but holds no sensitive
data, plus the `isJoiningSelf()` rule (Q6) to allow a strictly-
whitelisted self-add. This pattern (a read-only public lookup table
sitting in front of the protected resource) is now my default for
"share-by-link"-style flows.

**If I restarted tomorrow.** I would keep the same Flutter +
Firebase substrate but I'd:

1. Bring `firebase emulators-suite` into the repo from day one so
   security-rule changes can be unit-tested instead of caught only
   at runtime.
2. Add a thin server-side write API in Cloud Functions for
   *every* mutation, instead of letting clients write directly to
   Firestore. This collapses the rules surface to "client can read
   what it owns; only Functions can write" — a much smaller blast
   radius for any future schema mistake.

**Evidence.** `submission/BUG_LOG.md` entry 2,
`firestore.rules` (`joinCodes` block + `isJoiningSelf`),
`lib/features/session/data/session_repository.dart`
(`createSession`, `joinByCode`, `endSession`).

---

## Appendix — Test inventory

```
$ flutter test
00:02 +62: All tests passed!
```

Files (62 cases total):

- `test/widget_test.dart` — theme smoke tests.
- `test/features/auth/auth_error_messages_test.dart` —
  describeFirebaseAuthError × 11 cases (Q8).
- `test/features/chat/chat_repository_test.dart` — chat read/write
  contracts.
- `test/features/recommendations/track_recommender_test.dart` —
  rule-based suggester scoring + dedup + topK + staleness.
- `test/features/recommendations/fairness_ranker_test.dart` —
  graduate fairness module: participation boost, played penalty,
  recency, explainability factors.
- `test/features/session/mood_summary_test.dart` — vote-weighted
  mood derivation.
- `test/features/session/queue_repository_test.dart` —
  transaction-safe voting (Q3).
- `test/features/session/session_repository_test.dart` — full
  lifecycle: create → join → leave → end (Q11 / Q14 evidence).
- `test/features/session/spotify_track_search_repository_test.dart` —
  fallback contract + parsing (Q7).
