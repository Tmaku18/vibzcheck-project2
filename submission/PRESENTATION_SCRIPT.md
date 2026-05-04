# Vibzcheck — Presentation Script

**Speaker.** Tanaka Makuvaza · CSC 6370 · CRN 13598
**Length budget.** 22 minutes of spoken content (rubric window: 20-25 min).
**Mode.** Solo. Live demo on two side-by-side Android emulators
(emulator-5554 = Device A / owner; emulator-5556 = Device B / joiner).

The script is structured as **18 slides** that fit naturally into the
14-question coverage required by the rubric. The questions can be
answered in any order, so this script reorders them into a narrative arc
rather than the categorical order of the answer key in
[`CURATED_QUESTIONS.md`](CURATED_QUESTIONS.md). A small icon in each
slide header tells you which curated question(s) the slide is covering.

> **Stage rule.** Every slide says one thing. If a slide says two
> things, cut one. Anything you cut you can still say out loud.

> **Tip.** Run `flutter test` once on the projector at the start of the
> demo so the green `+62 All tests passed!` line is visible. It buys
> credibility for the rest of the presentation.

---

## Slide-by-slide script

### Slide 1 — Title (00:00 - 00:30, ~30 s)

**On screen.** "Vibzcheck — Collaborative real-time listening sessions
on Flutter + Firebase." Tanaka Makuvaza · CSC 6370 · Solo, M.S. graduate
track · Project 2 · Spring 2026.

**Say.**

> Good afternoon. I'm Tanaka Makuvaza, and for Project 2 I built
> Vibzcheck — a Flutter and Firebase app where a host can start a
> listening session, friends join with a six-character code, and
> everyone votes on a shared queue in real time. I'll walk you through
> the build, the architecture, the bugs I had to chase, and the choices
> I'd defend in code.

---

### Slide 2 — One-screen demo (00:30 - 02:30, ~2 min)

**On screen.** Both emulators, side by side. Live app.

**Do.**

1. Sign in on Device A (Alice). Show the home screen with one prior
   session.
2. Tap **Start a session** → name it `Demo` → land in the session
   screen. Read out the 6-character join code on screen.
3. Switch to Device B (Bob). Sign in. Tap **Join with code** → type the
   code → land in the same session.
4. On Device A, tap **Add a track** → search "weeknd" → tap the **+**
   on Blinding Lights. The track appears on **both** screens within a
   second.
5. On Device B, upvote the track. Score flips to 1 on Device A.
6. Open the **Suggestions** tab on Device A — point at the per-factor
   "why?" expander on the top suggestion.

**Say while doing it.** (Don't read these — improvise around them.)

> Notice nothing here is polled. That's a Firestore stream listener on
> the queue subcollection. The vote tap on Bob's device is a
> transaction so even if Alice voted at the same instant, neither one
> overwrites the other.

---

### Slide 3 — Stack at a glance (02:30 - 03:00, ~30 s)

**On screen.** Single table:

| Layer | Choice | Why |
| --- | --- | --- |
| Mobile | Flutter 3.38 / Dart 3.10 | Single codebase, Material 3. |
| State | Riverpod 3 | Compile-checked DI, auto-dispose listeners. |
| Routing | go_router 17 | Declarative + auth-aware redirect. |
| Identity | firebase_auth | Email + password. |
| Database | cloud_firestore | Real-time queue, votes, chat. |
| Files | firebase_storage | Avatars. |
| Push | firebase_messaging | Invites and vote rounds. |
| Server | cloud_functions (Node 22 / TS) | Spotify bridge, secret holder. |

**Say.**

> All five required Firebase services are live, plus Cloud Functions
> for the Spotify bridge so the Client Secret never ships in the APK.
> One declarative GoRouter handles all navigation including auth-aware
> redirects.

---

### Slide 4 — Q1: Build sequence and risk reduction *(Implementation #1)*

**On screen.** Three boxes left-to-right with arrows: **(1) Queue +
voting** → **(2) Spotify Cloud Function** → **(3) Recommendations**.

**Say.**

> The three hardest features were the live queue with voting, the
> Spotify cloud function bridge, and the recommendations module. I
> built them in that order on purpose, because each one validated the
> substrate the next one assumed. Voting touched auth, Firestore,
> transactions, and security rules together — if any of those were
> broken, every later feature would inherit the same break. The
> Spotify function came next because at that point the queue could
> already accept tracks from a mock source, so swapping in a real
> Spotify-backed repository was a one-line provider change. And
> recommendations went last because they consume what the first two
> features produce.
>
> This staircase shape is how I de-risked solo: every layer had a
> tested predecessor before any new uncertainty was added on top.

---

### Slide 5 — Q4 + Q5: Architecture and navigation *(Architecture #1, #2)*

**On screen.** A simple component diagram:

- `SessionScreen` (tab host)
  - `QueueTrackTile`
  - `SuggestionsCard`
  - `ChatScreen`
- `GoRouter` with auth redirect on the side.

**Say.**

> SessionScreen used to do everything itself — queue, chat,
> suggestions, member roster — and it got too big to read in one
> screenful. I split it into three composable widgets. QueueTrackTile
> owns one row of the queue and its vote button state. SuggestionsCard
> owns the AI helper and is completely decoupled from the queue.
> ChatScreen is its own route so it can be backgrounded without losing
> state. The screen itself is now mostly TabBarView plumbing.
>
> For navigation I picked one declarative GoRouter. It has an
> auth-aware redirect — there's a small Listenable adapter that
> rebroadcasts FirebaseAuth.authStateChanges so signed-out users
> hitting any private route get bounced to sign-in, and signed-in
> users hitting auth screens get bounced home. Adding a new private
> route requires zero changes to the redirect.

---

### Slide 6 — Q10: Firestore data model *(Firebase #1)*

**On screen.**

```
users/{uid}
sessions/{sessionId}
  ├── members/{uid}
  ├── queue/{trackId}
  ├── messages/{messageId}
  └── suggestions/{snapshotId}
joinCodes/{code}    ← public lookup
```

**Say.**

> Three top-level collections — users, sessions, and joinCodes — and
> four subcollections under each session.
>
> I picked subcollections under sessions instead of parallel
> top-level collections because a single security rule on
> `sessions/{id}/queue/{trackId}` can call `isSessionMember(id)`
> *once* per request. If queue tracks lived in their own top-level
> collection, every doc would have to repeat the membership lookup.
> It also means Riverpod listener teardown is automatic when the user
> navigates out of the session screen.
>
> The interesting one is `joinCodes`. It's deliberately top-level and
> public-readable. I'll explain why on the next slide.

---

### Slide 7 — Q14 + Q6: Tech debt and the join-by-code rule *(Reflection, Architecture #3)*

**On screen.**

```
v1 (broken)        v2 (shipped)
sessions where     joinCodes/{code} → sessionId
  code == ?        sessions update via isJoiningSelf()
```

**Say.**

> My biggest piece of technical debt came from Phase 2. The original
> join-by-code flow was a single Firestore query —
> `sessions where code equals ?`. That query needed read access on the
> entire sessions collection for every signed-in user. The Phase 2
> rules permitted it implicitly because I hadn't tightened them yet.
>
> The first time I tightened reads to "members and owner only" — which
> the rubric specifically rewards — join-by-code broke end-to-end. A
> non-member literally couldn't see any session, so no query
> succeeded. That's the chicken-and-egg I document as Bug 2 in the
> bug log.
>
> I solved it with two changes. First, a separate `joinCodes`
> collection mapping code to sessionId — anyone signed-in can read it
> but it holds no sensitive data. Second, this rule.

**Click to reveal the rule.**

```firestore
function isJoiningSelf() {
  return isSignedIn()
    && !(request.auth.uid in resource.data.memberIds)
    && request.auth.uid in request.resource.data.memberIds
    && request.resource.data.diff(resource.data).affectedKeys()
        .hasOnly(['memberIds', 'memberCount', 'updatedAt']);
}
```

> A non-member can update a session document **only** to add their own
> UID to memberIds and bump the denormalised counters. The
> `affectedKeys.hasOnly` whitelist is the safety net — they can't
> change ownership, status, or the current track. This pattern, a
> read-only public lookup table sitting in front of the protected
> resource, is now my default for anything share-by-link.

---

### Slide 8 — Q11: Composite index and read cost *(Firebase #2)*

**On screen.**

```dart
_sessions
  .where('memberIds', arrayContains: uid)
  .orderBy('updatedAt', descending: true)
  .snapshots();
```

```json
{
  "collectionGroup": "sessions",
  "fields": [
    {"fieldPath": "memberIds", "arrayConfig": "CONTAINS"},
    {"fieldPath": "updatedAt", "order": "DESCENDING"}
  ]
}
```

**Say.**

> This is the home-screen "sessions I'm in" query. It combines an
> array-contains filter with an orderBy on a different field, which
> Firestore requires a composite index for. The index lives in
> `firestore.indexes.json` so it's reproducible — there is no
> "click-once" config in this repo.
>
> On read cost: the index is write-amplifying. Every session update
> writes one extra index entry per member. For a 10-member session
> that's 10 index entries per `updatedAt` bump. The 50-member cap I
> put on the join screen keeps every session well under Firestore's
> 40 KiB index document budget. Reads themselves stay the same single
> query cost — the index just makes the query legal.
>
> This index, plus a parallel one for the queue listener, was found
> the hard way: the home screen spun forever for both emulators
> after the join-by-code rewrite. `adb logcat` showed
> `FAILED_PRECONDITION: query requires an index`. That's Bug 3 in the
> bug log.

---

### Slide 9 — Q12: Auth-scoped rule *(Firebase #3)*

**On screen.**

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

**Say.**

> Every user can read or write only their own profile document. An
> unauthenticated request has `request.auth == null`, so `isSignedIn`
> is false and the request fails. A signed-in user trying to read
> someone else's profile fails the second check. Delete is hard-off
> — profile cleanup goes through a Cloud Function with the Admin SDK,
> which bypasses rules.
>
> I tested this two ways. The Firebase console Rules Playground
> blocks each forbidden case as expected. And in `session_repository`
> tests against a fake Firestore, the same shape of writes our rules
> expect is what passes — so a code-side regression that breaks the
> rule contract would also break the unit tests.

---

### Slide 10 — Q13: FCM token lifecycle *(Firebase #4)*

**On screen.** Numbered timeline:

1. Sign-in → request permission
2. `getToken()` → store in `users/{uid}.fcmTokens` (array)
3. `onTokenRefresh` → arrayUnion + arrayRemove
4. Foreground: SnackBar via active ScaffoldMessenger
5. Background / terminated: top-level `vibzcheckFcmBackgroundHandler`
6. Sign-out → arrayRemove old token

**Say.**

> FCM has the most state of any feature, so I gave it its own service.
> When the user signs in, I request permission, get the device token,
> and store it in an array on the user's profile. The array shape lets
> one user accumulate tokens across multiple devices. `onTokenRefresh`
> pipes new tokens through arrayUnion and removes the old via
> arrayRemove.
>
> Delivery has three modes. Foreground gets a SnackBar via the active
> ScaffoldMessenger. Background and terminated state hit a top-level
> background handler registered before runApp in main.dart — it has
> to be top-level so the platform can spin up a fresh isolate.
> Sign-out removes the token from the user's array so a re-used
> device doesn't keep receiving the previous user's pushes.

---

### Slide 11 — Q3: Sync bug and safeguards *(Implementation #3)*

**On screen.**

```dart
// Before (subtly wrong)
votes[uid] = null;

// After (atomic, transaction-safe)
updates['votes.$uid'] = FieldValue.delete();
tx.update(trackRef, updates);
```

**Say.**

> The most subtle bug I shipped and caught: tapping upvote twice
> toggled the UI off but left `voteScore = 1` in Firestore. The naive
> implementation cleared a vote with `votes[uid] = null`. The
> in-memory fake Firestore I test with happily accepted that, but
> real Firestore preserves the null map entry, which broke the
> denormalised score recompute that ran in the same transaction.
>
> The fix is the second snippet — a dotted-path delete inside the
> same transaction, so the per-user key is removed atomically while
> the score, upvotes, and downvotes are recomputed. The
> `upvoting twice toggles the vote off` test in
> `queue_repository_test.dart` now pins this contract.

---

### Slide 12 — Q7 + Q2: Failure case ownership *(Testing #1, Implementation #2)*

**On screen.**

```dart
} on FirebaseFunctionsException catch (e, stack) {
  if (e.code == 'unauthenticated' || e.code == 'failed-precondition') {
    rethrow; // user / config errors fallback can't fix
  }
  return _fallback.search(query); // mock catalogue
}
```

**Say.**

> The first version of my Spotify repository rethrew every
> FirebaseFunctionsException, which meant a single Cloud Function
> hiccup emptied the Add Track screen. I redesigned the response so
> the repo *narrows* the rethrow set: only `unauthenticated` and
> `failed-precondition` come through, because those are real user
> errors a fallback would mask. Everything else — `unavailable`, rate
> limits, my own Spotify CRLF bug — falls through to a mock catalogue
> so the user always sees results.
>
> I also reworked the Add Track screen itself. Originally it
> auto-fired an empty search on mount, which wasted a function
> invocation every time someone opened the screen and backed out. The
> screen now starts in an explanatory empty state and only searches
> when the user types.

---

### Slide 13 — Q8: Auth error UX *(Testing #2)*

**On screen.** Three different error codes collapsing into one line:

```
user-not-found        ┐
wrong-password        ├──→  "Email or password is incorrect."
invalid-credential    ┘
```

**Say.**

> When sign-in fails, attackers must not be able to figure out which
> half of the credential pair was wrong — that would let them
> enumerate which emails have accounts. So my error mapper
> deliberately collapses three different Firebase Auth codes
> — `user-not-found`, `wrong-password`, and `invalid-credential` —
> into one shared "Email or password is incorrect." line. Eleven
> tests in `auth_error_messages_test.dart` pin this exhaustively, so
> a future addition to the switch is forced to ship with a paired
> test.

---

### Slide 14 — Q9: Performance under real use *(Testing #3)*

**On screen.** Two log lines side by side:

```
05-03 logcat:  FAILED_PRECONDITION: query requires an index
05-03 logcat:  (resolved 187 ms after index deploy)
```

**Say.**

> The home screen sessions list spun forever for both emulators after
> the join-by-code rewrite. I profiled it the same way I'd profile
> any production issue — `adb logcat` running in a side terminal —
> and the smoking gun was right there: `FAILED_PRECONDITION, query
> requires an index`. I added the composite index to
> `firestore.indexes.json`, redeployed, and first emission dropped to
> sub-200 milliseconds. A near-identical bug recurred for the queue
> listener once Phase 3 added the `played == false` filter; the same
> playbook resolved it.
>
> Takeaway: when a request leaves the device, the right first move
> is to inspect the *server's* logs, not the client's.

---

### Slide 15 — AI helper + graduate fairness module *(supports Q1)*

**On screen.** Live screen capture of the SuggestionsCard with one
expanded "why?" panel showing factors: Mood match +0.62, Genre
overlap +0.31, Variety -0.18, Recency 0.

**Say.**

> The AI must-solve helper is a transparent rule-based recommender.
> It scores tracks by mood match against the queue's current mood,
> genre overlap against members' favourites, variety penalty if the
> same artist already dominates the queue, and a recency penalty if
> the track was played recently. Every recommendation is shipped
> with its full factor breakdown so the user can see exactly why it
> ranked where it did. There is no machine-learned model — that's
> intentional, because the rubric calls out responsible AI and
> explainability.
>
> The graduate fairness module is the second pass. It re-ranks the
> queue using member participation — quieter members get a small
> boost so they aren't drowned out by the loudest voters. Same
> explainability shape: every re-rank is shown with the factor it
> won on. Both modules have full tests in
> `track_recommender_test.dart` and `fairness_ranker_test.dart`.

---

### Slide 16 — Tests, evidence, and the bug log *(supports rubric)*

**On screen.** Three blocks:

```
$ flutter test
00:05 +62: All tests passed!
```

```
submission/
  BUG_LOG.md            (six bugs, root-cause format)
  CURATED_QUESTIONS.md  (14 questions, full answers)
  screenshots/
  Vibzcheck-1.0.0-release.apk
```

**Say.**

> Sixty-two tests, all green: nine test files covering the
> recommender, the fairness ranker, the queue voting transaction,
> the session lifecycle, the Spotify repository fallback contract,
> the auth error mapping, the chat repo, the mood summary, and theme
> rendering.
>
> Everything the grader needs lives in `submission/`. The bug log is
> the diary of the six hardest fixes — issue, root cause, fix, files
> touched, commit hash. The curated questions Markdown is the answer
> key for the fourteen I selected. The release APK is signed and
> ready to sideload.

---

### Slide 17 — If I restarted tomorrow *(supports Q14)*

**On screen.**

1. **Firebase emulator-suite** wired in from day one.
2. **All writes through Cloud Functions** (clients read-only).

**Say.**

> If I restarted tomorrow on the same Flutter and Firebase substrate,
> two things would change.
>
> One, the Firebase emulator suite would be in the repo from day one.
> Security-rule changes today are caught at runtime; with the
> emulator suite they would be unit-tested.
>
> Two, every mutation would go through a Cloud Function with the
> Admin SDK rather than directly from the client to Firestore. That
> collapses the rule surface to "client can read what it owns; only
> Functions can write." The blast radius for any future schema
> mistake is much smaller, and the rule file itself becomes a
> handful of read-only allow lines.

---

### Slide 18 — Close (~30 s)

**On screen.** "Vibzcheck — github.com/Tmaku18/vibzcheck-project2"
plus a QR code if you want to add one.

**Say.**

> That's Vibzcheck. Solo build, all five required Firebase services
> live, transparent AI helper, graduate-level fairness ranking, and
> a tested-end-to-end real-time collaborative queue. The repo is
> public, the APK is signed, and I'm happy to take questions.

---

## Timing budget

| Block | Slides | Time |
| --- | --- | --- |
| Open + stack | 1, 2, 3 | 03:00 |
| Implementation arc | 4 | 01:00 |
| Architecture + data | 5, 6, 7, 8 | 06:00 |
| Firebase deep cuts | 9, 10 | 02:30 |
| Bugs + UX recovery | 11, 12, 13, 14 | 05:00 |
| AI + grad extension | 15 | 02:00 |
| Evidence + reflection + close | 16, 17, 18 | 02:30 |
| **Total spoken content** | | **22:00** |
| Buffer for live demo / Q&A | | 02:00 - 03:00 |
| **Wall-clock window** | | **24-25 min** |

---

## Quick rehearsal checklist

- `flutter test` once on the projector → 62 passes line is visible.
- Both emulators powered on, signed in to `alice@vibzcheck.test` and
  `bob@vibzcheck.test`, paused on the home screen.
- One pre-created session named `Demo` already exists on Alice's
  account so the home list is non-empty.
- A second session whose code Bob will type lives in your speaker
  notes — pre-generate it, write it on a sticky.
- `adb logcat` running in a side terminal with the filter
  `flutter|FAILED_PRECONDITION` so you can pop to it instantly if a
  question goes there.
- `firebase functions:log --lines 5` cached in shell history so you
  can show live function output if asked.
