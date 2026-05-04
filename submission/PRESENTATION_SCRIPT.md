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
> demo so the green `+63 All tests passed!` line is visible. It buys
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

**On screen.** Both emulators side by side, plus two real captures of
the same session viewed from each phone. Look at E85 — Device A shows
**1 upvote**, Device B shows **2** after the joiner upvotes. That
one-vote difference is the realtime-sync proof I'm about to recreate
live.

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

> The two screenshots on the right are the static version of what
> you're seeing live: same session, two phones, vote count drifts apart
> for a moment and then catches up. Nothing here is polled. That's a
> Firestore stream listener on the queue subcollection. The vote tap
> on Bob's device is a transaction, so even if Alice voted at the same
> instant, neither one overwrites the other.

---

### Slide 3 — What I built it with (02:30 - 03:00, ~30 s)

**On screen.** A bullet list mapping each piece of the stack to the
job it actually does for the user — Flutter for the cross-platform
app, Riverpod for state, go_router for navigation, the four required
Firebase services (Auth, Firestore, Storage, Cloud Messaging) for
identity, live data, avatars, and pushes, and Cloud Functions so the
Spotify Client Secret never ships in the APK.

**Say.**

> What you're looking at is the whole stack reduced to one line per
> piece. The thing I want you to take away from this slide isn't any
> individual library — it's that all five required Firebase services
> are live in the build I just demoed, and the one piece of
> server-side code, the Spotify bridge, exists specifically so the
> Client Secret never gets shipped inside the APK. Everything below
> the dotted line on screen is for the user; everything above it is
> for me, the developer.

---

### Slide 4 — Q1: Build sequence and risk reduction *(Implementation #1)*

**On screen.** Three numbered steps, each with a one-line "why this
order" reason underneath: queue + voting first, Spotify cloud function
second, AI recommendations third.

**Say.**

> The three boxes on screen are my hardest features in the order I
> built them — and the order matters. Voting first, because it
> exercises auth, Firestore, transactions, and security rules
> together. If any of those are broken every later feature inherits
> the same break. The Spotify function second, because at that point
> the queue could already accept tracks from a mock source, so
> swapping in the real Spotify-backed repo was a one-line provider
> change. Recommendations last, because they consume what the first
> two features produce — building them last meant they never had to
> be redesigned around schema changes.
>
> Read top to bottom on the slide and that's how I de-risked solo:
> every layer had a tested predecessor before any new uncertainty was
> added on top.

---

### Slide 5 — Q4 + Q5: Architecture and navigation *(Architecture #1, #2)*

**On screen.** Bullets for the three composable widgets I split the
session screen into, with a real chat screenshot on the right showing
ChatScreen as its own route.

**Say.**

> The session screen used to do everything itself — queue, chat,
> suggestions, member roster — and it got too big to read in one
> screenful. The bullets on screen are the three pieces I broke it
> into: QueueTrackTile owns one row of the queue and its vote button,
> SuggestionsCard owns the AI helper and is completely decoupled from
> the queue, and ChatScreen — the screenshot on the right — is its
> own route, so you can switch away to it and the queue keeps streaming
> behind you.
>
> For navigation I picked one declarative GoRouter with an auth-aware
> redirect. There's a small Listenable adapter that rebroadcasts
> FirebaseAuth's auth-state changes, so a signed-out user hitting any
> private route gets bounced to sign-in, and a signed-in user hitting
> the auth screens gets bounced home. Adding a new private route
> requires zero changes to the redirect.

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

Bullets to the left of the tree summarise the design intent; the
home-screen sessions list on the right is the live result of this
shape.

**Say.**

> What's on screen is the whole data model on one page. Three
> top-level collections — users, sessions, and joinCodes — and four
> subcollections under each session.
>
> Read the indented branches: members, queue, messages, suggestions
> all live *under* their session. I picked subcollections instead of
> parallel top-level collections because a single security rule on
> `sessions/{id}/queue/{trackId}` can call `isSessionMember(id)`
> *once* per request. If queue tracks lived in their own top-level
> collection, every doc would have to repeat the membership lookup.
> It also means Riverpod listener teardown is automatic when the user
> navigates out of the session screen.
>
> The interesting one is the bottom line — `joinCodes/{code}`. It's
> deliberately top-level and public-readable. The next slide is
> entirely about why.

---

### Slide 7 — Q14 + Q6: Tech debt and the join-by-code rule *(Reflection, Architecture #3)*

**On screen.** Two real screenshots — host's "Start a session" on the
left and joiner's "Enter the join code" on the right — sandwich the
`isJoiningSelf()` rule that makes the join flow safe:

```firestore
function isJoiningSelf() {
  return isSignedIn()
    && !(request.auth.uid in resource.data.memberIds)
    && request.auth.uid in request.resource.data.memberIds
    && request.resource.data.diff(resource.data).affectedKeys()
        .hasOnly(['memberIds', 'memberCount', 'updatedAt']);
}
```

**Say.**

> Both screenshots show the same flow from each side — the host
> creates the room and reads off the code, the joiner types it on
> their phone. My biggest piece of technical debt came from making
> that flow work safely.
>
> The original join-by-code was a single Firestore query —
> `sessions where code equals ?`. That query needed read access on
> the entire sessions collection for every signed-in user. The first
> time I tightened reads to "members and owner only" — which the
> rubric specifically rewards — join-by-code broke end-to-end.
> A non-member literally couldn't see any session, so no query
> succeeded. That's the chicken-and-egg I document as Bug 2 in the
> bug log.
>
> The rule on screen is half of the fix. Read it line by line. Line
> two and three say "the caller is currently not a member, but is in
> the new memberIds list" — in plain English, "they're trying to add
> themselves." Line four is the safety net: `affectedKeys.hasOnly`
> says they can change *only* the membership-related fields. They
> can't sneak in a change to ownerId, status, or the current track.
> The other half of the fix, which I won't show in code, is a
> read-only `joinCodes` lookup table sitting in front of the protected
> sessions collection. That two-part pattern — public lookup plus a
> tightly-whitelisted self-add — is now my default for any
> share-by-link flow.

---

### Slide 8 — Q11: Composite index and read cost *(Firebase #2)*

**On screen.** Two snippets stacked: the Dart query that drives the
home screen, and the JSON composite-index definition that makes it
legal. The home-sessions screenshot on the right is the live result.

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

> The top snippet is the home screen's "sessions I'm in" query.
> Notice it combines an `arrayContains` filter with an `orderBy` on a
> different field — that combination is the one Firestore requires a
> composite index for. Without one you don't get a slow query; you get
> no query at all.
>
> The bottom snippet is that index, declared in
> `firestore.indexes.json`. It lives in source control so the infra is
> reproducible — there is no click-once console config in this repo.
>
> On read cost — and this is the part graders ask about — the index is
> *write*-amplifying, not read-amplifying. Every session update writes
> one extra index entry per member. For a 10-member session that's 10
> entries per `updatedAt` bump. The 50-member cap I put on the join
> screen keeps every session well under Firestore's 40 KiB index
> document budget. Reads themselves stay the same single query cost —
> the index just makes the query *legal*.
>
> The screenshot on the right is the result: this index, plus a
> parallel one for the queue listener, is what makes the home list on
> the right resolve in under 200 milliseconds. They were both found
> the hard way — `adb logcat` showed `FAILED_PRECONDITION`. That's
> Bug 3 in the bug log.

---

### Slide 9 — Q12: Auth-scoped rule *(Firebase #3)*

**On screen.** The `/users/{uid}` match block plus the `isSelf()`
helper, with the sign-up screenshot on the right showing where this
rule first kicks in for a brand-new user:

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

> The four `allow` lines on screen all delegate to the same one-line
> helper at the bottom: `isSelf(uid)`. Walk down the block and you can
> read the entire policy: every user can read or write **only** their
> own profile document. An unauthenticated request has
> `request.auth == null`, so `isSignedIn()` is false and every line
> fails. A signed-in user trying to read someone else's profile fails
> the second check, `request.auth.uid == uid`.
>
> Notice `delete` is hard-off — `if false`. Profile cleanup goes
> through a Cloud Function with the Admin SDK, which bypasses rules.
> That's the same pattern I'd use everywhere if I rebuilt the project
> tomorrow, which is the last slide.
>
> I tested this rule two ways. The Firebase console Rules Playground
> blocks each forbidden case as expected, and the
> `session_repository` tests against a fake Firestore use the same
> shape of writes our rules expect — so a code-side regression that
> breaks the rule contract would also break the unit tests.

---

### Slide 10 — Q13: FCM token lifecycle *(Firebase #4)*

**On screen.** A six-step numbered timeline of what happens to a push
token from sign-in to sign-out:

1. Sign-in → request permission
2. `getToken()` → store in `users/{uid}.fcmTokens` (array)
3. `onTokenRefresh` → arrayUnion + arrayRemove
4. Foreground: SnackBar via active ScaffoldMessenger
5. Background / terminated: top-level `vibzcheckFcmBackgroundHandler`
6. Sign-out → arrayRemove old token

**Say.**

> Walk down the timeline on screen and that's the whole lifecycle.
> Step one and two: when the user signs in, I request permission and
> store the device token in an array on the user's profile. The array
> shape lets one user accumulate tokens across multiple devices.
> Step three handles the case where Firebase rotates the token —
> arrayUnion the new one, arrayRemove the old one.
>
> Steps four and five are where the design has to be careful.
> Foreground delivery is easy — a SnackBar via the active
> ScaffoldMessenger. Background and terminated state hit a top-level
> background handler that has to be registered *before* `runApp`, so
> the platform can spin up a fresh isolate to receive the push.
>
> Step six is the one most apps forget. On sign-out I `arrayRemove`
> the token, so a re-used device doesn't keep receiving the previous
> user's pushes.

---

### Slide 11 — Q3: Sync bug and safeguards *(Implementation #3)*

**On screen.** The fixed snippet from `QueueRepository.castVote`,
plus a queue screenshot showing votes settled in their final
correct state:

```dart
if (effectiveVote == 0) {
  updates['votes.$uid'] = FieldValue.delete();
} else {
  updates['votes.$uid'] = effectiveVote;
}
tx.update(trackRef, updates);
```

**Say.**

> The most subtle bug I shipped and caught: tapping upvote twice
> toggled the UI off but left `voteScore = 1` in Firestore. The naive
> implementation cleared a vote with `votes[uid] = null`. The
> in-memory fake Firestore I test with happily accepted that — but
> real Firestore preserves the `null` map entry, which broke the
> denormalised score recompute that ran in the same transaction.
>
> The fix is on screen. Read it top to bottom: when the new effective
> vote is zero we use a dotted-path delete (`votes.$uid` set to
> `FieldValue.delete()`); when it's plus or minus one we just set the
> value. Either way, the whole flip happens inside one
> `tx.update(trackRef, updates)` call, which means score, upvotes,
> downvotes, and the per-user key all change atomically.
>
> The queue screenshot on the right is the visual proof: the upvote
> count is what the math says it should be, on both phones, every
> time. The "upvoting twice toggles the vote off" test in
> `queue_repository_test.dart` now pins this contract — that's how I
> know it can't regress.

---

### Slide 12 — Q7 + Q2: Failure case ownership *(Testing #1, Implementation #2)*

**On screen.** The `try/catch` in
`spotify_track_search_repository.dart` showing exactly which errors
get rethrown vs which fall back to the mock catalogue, plus the Add
Track screen successfully searching "Drake" through the live function:

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
> `FirebaseFunctionsException`, which meant a single Cloud Function
> hiccup emptied the Add Track screen. I redesigned it to *narrow*
> the rethrow set — that's exactly what the snippet on screen shows.
> Only `unauthenticated` and `failed-precondition` come through,
> because those are real user errors a fallback would mask.
> Everything else — `unavailable`, rate limits, my own Spotify CRLF
> bug — falls through to the mock catalogue on the next line so the
> user always sees results.
>
> The screenshot on the right is the happy path — the user types
> "drake," the function returns real Spotify results, the screen
> populates. If the function falls over, the user sees the same
> screen filled with the seed catalogue instead of an empty box.
>
> I also reworked the screen itself. Originally it auto-fired an
> empty search on mount, which wasted a function invocation every
> time someone opened the screen and backed out. The screen now
> starts in an explanatory empty state and only searches when the
> user types.

---

### Slide 13 — Q8: Auth error UX *(Testing #2)*

**On screen.** Three different Firebase Auth codes collapsing into
one shared user-facing line, plus the sign-in screen on the right
where the user actually sees that line:

```
user-not-found        ┐
wrong-password        ├──→  "Email or password is incorrect."
invalid-credential    ┘
```

**Say.**

> When sign-in fails, attackers must not be able to figure out which
> half of the credential pair was wrong — that would let them
> enumerate which emails have accounts.
>
> What's on screen is the rule I enforce. Three different Firebase
> Auth codes — `user-not-found`, `wrong-password`, and
> `invalid-credential` — all collapse into one shared line: "Email or
> password is incorrect." That's what the user on the right sees
> regardless of which code Firebase returned.
>
> Eleven tests in `auth_error_messages_test.dart` pin this
> exhaustively, so a future addition to the switch is forced to ship
> with a paired test — the safety property is enforced at the test
> level, not just by convention.

---

### Slide 14 — Q9: Performance under real use *(Testing #3)*

**On screen.** Two real `adb logcat` lines from the bug hunt: the
`FAILED_PRECONDITION` crash, and the 187 ms recovery after the index
deploy.

```
05-03 logcat:  FAILED_PRECONDITION: query requires an index
05-03 logcat:  (resolved 187 ms after index deploy)
```

**Say.**

> The home screen sessions list spun forever for both emulators after
> the join-by-code rewrite. I profiled it the same way I'd profile
> any production issue — `adb logcat` running in a side terminal —
> and the smoking gun was right there. That's the first line on
> screen. `FAILED_PRECONDITION, query requires an index`.
>
> I added the composite index to `firestore.indexes.json`,
> redeployed, and the second line on screen is what came back: 187
> milliseconds. A near-identical bug recurred for the queue listener
> once Phase 3 added the `played == false` filter — same playbook
> resolved it.
>
> Takeaway: when a request leaves the device, the right first move
> is to inspect the *server's* logs, not the client's.

---

### Slide 15 — AI helper + graduate fairness module *(supports Q1)*

**On screen.** The four scoring factors the recommender uses, plus a
real screen capture of the SuggestionsCard with one expanded "why?"
panel showing factors: Mood match +0.62, Genre overlap +0.31,
Variety -0.18, Recency 0.

**Say.**

> The AI must-solve helper is a transparent rule-based recommender.
> The four bullets on screen are the entire model: it scores tracks
> by mood match against the queue's current mood, genre overlap
> against members' favourites, variety penalty if the same artist
> already dominates the queue, and a recency penalty if the track
> was played recently.
>
> The screenshot on the right is the most important part of this
> slide. Every recommendation is shipped with that "why?" expander
> showing the per-factor breakdown — the user can see exactly why a
> track ranked where it did. There is no machine-learned model.
> That's intentional, because the rubric calls out responsible AI
> and explainability.
>
> The graduate fairness module is the second pass. It re-ranks the
> queue using member participation — quieter members get a small
> boost so they aren't drowned out by the loudest voters. Same
> explainability shape: every re-rank is shown with the factor it
> won on. Both modules have full tests in
> `track_recommender_test.dart` and `fairness_ranker_test.dart`.

---

### Slide 16 — Tests, evidence, and the bug log *(supports rubric)*

**On screen.** Two real terminal blocks: the `flutter test` pass
line and the contents of the `submission/` folder.

```
$ flutter test
00:02 +63: All tests passed!
```

```
submission/
  BUG_LOG.md            (seven bugs, root-cause format)
  CURATED_QUESTIONS.md  (14 questions, full answers)
  screenshots/
  Vibzcheck-1.0.0-release.apk
```

**Say.**

> The first block on screen is the test suite — sixty-three cases,
> all green. Nine test files covering the recommender, the fairness
> ranker, the queue voting transaction, the session lifecycle, the
> Spotify repository fallback contract, the auth error mapping, the
> chat repo, the mood summary, and theme rendering.
>
> The second block is everything the grader needs in one folder.
> The bug log is the diary of the seven hardest fixes — issue, root
> cause, fix, files touched, commit hash. The curated questions
> Markdown is the answer key for the fourteen I selected; the same
> content is also in a Word document for the rubric. The release
> APK is signed and ready to sideload onto any Android phone.

---

### Slide 17 — If I restarted tomorrow *(supports Q14)*

**On screen.**

1. **Firebase emulator-suite** wired in from day one.
2. **All writes through Cloud Functions** (clients read-only).

**Say.**

> If I restarted tomorrow on the same Flutter and Firebase substrate,
> the two numbered points on screen are what would change.
>
> One — the Firebase emulator suite would be in the repo from day
> one. Security-rule changes today are caught at runtime, which is
> how I found Bug 2 and Bug 7 the painful way; with the emulator
> suite they would be unit-tested.
>
> Two — every mutation would go through a Cloud Function with the
> Admin SDK rather than directly from the client to Firestore. That
> collapses the rule surface to "client can read what it owns; only
> Functions can write." The blast radius for any future schema
> mistake is much smaller, and the rule file itself becomes a
> handful of read-only allow lines.

---

### Slide 18 — Close (~30 s)

**On screen.** "Vibzcheck — github.com/Tmaku18/vibzcheck-project2"
plus the high-level pitch in one paragraph.

**Say.**

> That's Vibzcheck. Solo build, all five required Firebase services
> live, transparent AI helper, graduate-level fairness ranking, and
> a real-time collaborative queue tested end to end. The repo is
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

- `flutter test` once on the projector → 63 passes line is visible.
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
