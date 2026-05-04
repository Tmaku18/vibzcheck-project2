"""Generate Vibzcheck_Presentation.pptx programmatically.

Builds the 18-slide deck described in PRESENTATION_SCRIPT.md so the
speaker has a working starter file to refine in PowerPoint instead of
laying every slide out by hand. Title + body content go on the slide;
the "Say" script lives in the speaker-notes pane so it isn't visible
to the audience.

Run:
    python submission/make_presentation_pptx.py
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN
from pptx.util import Emu, Inches, Pt

OUT_PATH = Path(__file__).resolve().parent / "Vibzcheck_Presentation.pptx"

# --- Theme ----------------------------------------------------------------

BG_COLOR = RGBColor(0xFA, 0xFA, 0xFB)        # near-white
ACCENT = RGBColor(0x6B, 0x4D, 0xE6)          # Vibzcheck purple
INK = RGBColor(0x1F, 0x21, 0x29)             # near-black ink
INK_MUTED = RGBColor(0x4A, 0x52, 0x60)
RULE = RGBColor(0xE5, 0xE7, 0xEB)
CODE_BG = RGBColor(0xF1, 0xF2, 0xF6)
TAG_BG = RGBColor(0xEC, 0xE7, 0xFE)

SANS = "Calibri"
MONO = "Consolas"

SLIDE_W = Inches(13.333)
SLIDE_H = Inches(7.5)


# --- Domain ---------------------------------------------------------------


@dataclass
class Slide:
    """Single slide spec.

    `title` is the bold accent line at the top.
    `subtitle` (optional) is the smaller curated-question tag printed
    underneath the title.
    `body` is a list of "blocks". Each block is either a paragraph
    string (rendered as bullet) or a dict describing a more specialised
    shape (currently just `{"code": "..."}` for monospace code blocks
    and `{"table": [...]}` for two-column tables).
    `notes` is the speaker-only script text.
    """

    title: str
    subtitle: str | None
    body: list[object]
    notes: str
    layout: str = "content"  # "title" for cover slide


# --- Slide content (mirrors PRESENTATION_SCRIPT.md exactly) --------------

SLIDES: list[Slide] = [
    # 1 - Title
    Slide(
        layout="title",
        title="Vibzcheck",
        subtitle=(
            "Collaborative real-time listening sessions on Flutter + Firebase\n"
            "Tanaka Makuvaza  -  CSC 6370  -  CRN 13598  -  Project 2  -  Solo (M.S.)"
        ),
        body=[],
        notes=(
            "Good afternoon. I'm Tanaka Makuvaza, and for Project 2 I built "
            "Vibzcheck - a Flutter and Firebase app where a host can start a "
            "listening session, friends join with a six-character code, and "
            "everyone votes on a shared queue in real time. I'll walk you "
            "through the build, the architecture, the bugs I had to chase, "
            "and the choices I'd defend in code."
        ),
    ),
    # 2 - Live demo
    Slide(
        title="Live demo: two devices, one queue",
        subtitle="Demo (Slide 2)",
        body=[
            "Device A (Alice, owner): sign in -> Start a session 'Demo' -> read 6-char code aloud",
            "Device B (Bob, joiner): sign in -> Join with code -> lands in same session",
            "Device A: Add a track -> search 'weeknd' -> + on Blinding Lights",
            "Both screens update via Firestore stream listener (no polling)",
            "Device B upvotes -> score flips to 1 on Device A (transaction-safe)",
            "Open Suggestions tab -> expand the per-factor 'why?' panel",
        ],
        notes=(
            "Walk through the demo on the two emulators. Don't read the "
            "bullets - just narrate. Key thing to call out: 'Notice nothing "
            "here is polled. That's a Firestore stream listener on the queue "
            "subcollection. The vote tap on Bob's device is a transaction so "
            "even if Alice voted at the same instant, neither one overwrites "
            "the other.'"
        ),
    ),
    # 3 - Stack
    Slide(
        title="Stack at a glance",
        subtitle="What's wired, why it's wired",
        body=[
            {
                "table": [
                    ("Mobile", "Flutter 3.38 / Dart 3.10  -  single codebase, Material 3"),
                    ("State", "Riverpod 3  -  compile-checked DI, auto-dispose"),
                    ("Routing", "go_router 17  -  declarative + auth-aware redirect"),
                    ("Identity", "firebase_auth  -  email + password"),
                    ("Database", "cloud_firestore  -  real-time queue, votes, chat"),
                    ("Files", "firebase_storage  -  avatars"),
                    ("Push", "firebase_messaging  -  invites, vote rounds"),
                    ("Server", "cloud_functions (Node 22 / TS)  -  Spotify bridge, secrets"),
                ]
            }
        ],
        notes=(
            "All five required Firebase services are live, plus Cloud "
            "Functions for the Spotify bridge so the Client Secret never "
            "ships in the APK. One declarative GoRouter handles all "
            "navigation including auth-aware redirects."
        ),
    ),
    # 4 - Q1 build order
    Slide(
        title="Build sequence: a staircase, not a pile",
        subtitle="Q1  -  Implementation",
        body=[
            "1.  Queue + voting   (auth + Firestore + transactions + rules together)",
            "2.  Spotify Cloud Function   (server tier; queue already accepts any source)",
            "3.  Recommendations + fairness   (consume what 1 + 2 produced)",
            "Each layer had a tested predecessor before any new uncertainty was added",
        ],
        notes=(
            "The three hardest features were the live queue with voting, "
            "the Spotify cloud function bridge, and the recommendations "
            "module. I built them in that order on purpose, because each "
            "one validated the substrate the next one assumed. Voting "
            "touched auth, Firestore, transactions, and security rules "
            "together - if any were broken every later feature would "
            "inherit the same break. The Spotify function came next because "
            "the queue could already accept tracks from a mock source, so "
            "swapping in a real Spotify-backed repository was a one-line "
            "provider change. Recommendations went last because they "
            "consume what the first two features produce."
        ),
    ),
    # 5 - Architecture / navigation
    Slide(
        title="Screen decomposition + auth-aware routing",
        subtitle="Q4 + Q5  -  Architecture",
        body=[
            "SessionScreen (tab host)",
            "    -  QueueTrackTile         (one row, owns vote state)",
            "    -  SuggestionsCard        (AI helper, decoupled from queue)",
            "    -  ChatScreen             (own route, survives backgrounding)",
            "GoRouter with auth-aware redirect:",
            "    -  signed-out + private route  -> /sign-in",
            "    -  signed-in  + auth screen   -> /",
            "    -  zero changes to add a new private route",
        ],
        notes=(
            "SessionScreen used to do everything itself - queue, chat, "
            "suggestions, member roster - and it got too big to read in "
            "one screenful. I split it into three composable widgets. "
            "QueueTrackTile owns one row of the queue. SuggestionsCard "
            "owns the AI helper and is completely decoupled from the queue. "
            "ChatScreen is its own route so it can be backgrounded without "
            "losing state. The screen itself is now mostly TabBarView "
            "plumbing.\n\n"
            "For navigation I picked one declarative GoRouter with an "
            "auth-aware redirect. There's a small Listenable adapter that "
            "rebroadcasts FirebaseAuth.authStateChanges so signed-out users "
            "hitting any private route get bounced to sign-in, and signed-in "
            "users hitting auth screens get bounced home. Adding a new "
            "private route requires zero changes to the redirect."
        ),
    ),
    # 6 - Data model
    Slide(
        title="Firestore data model",
        subtitle="Q10  -  Firebase",
        body=[
            {
                "code": (
                    "users/{uid}\n"
                    "sessions/{sessionId}\n"
                    "  |-- members/{uid}\n"
                    "  |-- queue/{trackId}\n"
                    "  |-- messages/{messageId}\n"
                    "  +-- suggestions/{snapshotId}\n"
                    "joinCodes/{code}      <-- public lookup (read-only mapping)"
                )
            },
            "Subcollections under sessions: one rule call (isSessionMember) per request, not per doc",
            "Riverpod listener teardown is automatic when navigating out of a session",
            "joinCodes is deliberately top-level + public so non-members can resolve a code first",
        ],
        notes=(
            "Three top-level collections - users, sessions, joinCodes - and "
            "four subcollections under each session.\n\n"
            "I picked subcollections under sessions instead of parallel "
            "top-level collections because a single security rule on "
            "sessions/{id}/queue/{trackId} can call isSessionMember(id) "
            "*once* per request. If queue tracks lived in their own "
            "top-level collection, every doc would have to repeat the "
            "membership lookup. It also means Riverpod listener teardown is "
            "automatic when the user navigates out of the session screen.\n\n"
            "The interesting one is joinCodes. It's deliberately top-level "
            "and public-readable. I'll explain why on the next slide."
        ),
    ),
    # 7 - Tech debt + isJoiningSelf
    Slide(
        title="Join-by-code: the chicken-and-egg + the fix",
        subtitle="Q14 + Q6  -  Reflection + Architecture",
        body=[
            "v1 (broken):  sessions where code == ?      requires read on entire collection",
            "v2 (shipped): joinCodes/{code} -> sessionId   plus this rule:",
            {
                "code": (
                    "function isJoiningSelf() {\n"
                    "  return isSignedIn()\n"
                    "    && !(request.auth.uid in resource.data.memberIds)\n"
                    "    && request.auth.uid in request.resource.data.memberIds\n"
                    "    && request.resource.data.diff(resource.data).affectedKeys()\n"
                    "        .hasOnly(['memberIds', 'memberCount', 'updatedAt']);\n"
                    "}"
                )
            },
            "Strict whitelist: a non-member can ONLY add their own UID + bump counters",
            "Pattern is now my default for any 'share-by-link' flow",
        ],
        notes=(
            "My biggest piece of technical debt came from Phase 2. The "
            "original join-by-code flow was a single Firestore query - "
            "sessions where code equals ?. That query needed read access on "
            "the entire sessions collection for every signed-in user. The "
            "first time I tightened reads to 'members and owner only' - "
            "which the rubric specifically rewards - join-by-code broke "
            "end-to-end. A non-member literally couldn't see any session, "
            "so no query succeeded. That's the chicken-and-egg I document "
            "as Bug 2 in the bug log.\n\n"
            "I solved it with two changes. First, a separate joinCodes "
            "collection mapping code to sessionId - anyone signed-in can "
            "read it but it holds no sensitive data. Second, this rule. A "
            "non-member can update a session document only to add their "
            "own UID to memberIds and bump the denormalised counters. The "
            "affectedKeys.hasOnly whitelist is the safety net."
        ),
    ),
    # 8 - Composite index
    Slide(
        title="Composite index + read-cost trade-off",
        subtitle="Q11  -  Firebase",
        body=[
            "The query (home screen 'sessions I'm in'):",
            {
                "code": (
                    "_sessions\n"
                    "    .where('memberIds', arrayContains: uid)\n"
                    "    .orderBy('updatedAt', descending: true)\n"
                    "    .snapshots();"
                )
            },
            "The required composite index, declared in firestore.indexes.json:",
            {
                "code": (
                    "{\n"
                    "  \"collectionGroup\": \"sessions\",\n"
                    "  \"fields\": [\n"
                    "    { \"fieldPath\": \"memberIds\", \"arrayConfig\": \"CONTAINS\" },\n"
                    "    { \"fieldPath\": \"updatedAt\", \"order\": \"DESCENDING\" }\n"
                    "  ]\n"
                    "}"
                )
            },
            "Write-amplifying:  N members  ->  N index entries per updatedAt bump",
            "50-member cap keeps every session well under Firestore's 40 KiB index budget",
        ],
        notes=(
            "Array-contains plus an orderBy on a different field requires a "
            "composite index. The index lives in firestore.indexes.json so "
            "it's reproducible - no click-once console config in this repo.\n\n"
            "On read cost: the index is write-amplifying. Every session "
            "update writes one extra index entry per member. For a 10-member "
            "session that's 10 index entries per updatedAt bump. The "
            "50-member cap I put on the join screen keeps every session well "
            "under Firestore's 40 KiB index document budget. Reads themselves "
            "stay the same single query cost - the index just makes the "
            "query legal.\n\n"
            "This index, plus a parallel one for the queue listener, was "
            "found the hard way: the home screen spun forever after the "
            "join-by-code rewrite. adb logcat showed FAILED_PRECONDITION."
        ),
    ),
    # 9 - Auth-scoped rule
    Slide(
        title="Auth-scoped rule: users can only touch themselves",
        subtitle="Q12  -  Firebase",
        body=[
            {
                "code": (
                    "match /users/{uid} {\n"
                    "  allow read:   if isSelf(uid);\n"
                    "  allow create: if isSelf(uid);\n"
                    "  allow update: if isSelf(uid);\n"
                    "  allow delete: if false;\n"
                    "}\n\n"
                    "function isSelf(uid) {\n"
                    "  return isSignedIn() && request.auth.uid == uid;\n"
                    "}"
                )
            },
            "Unauthenticated:  request.auth == null  -> isSignedIn() false  -> denied",
            "Wrong UID:  request.auth.uid != uid  -> denied",
            "Hard-off delete:  cleanup goes through a Cloud Function (Admin SDK bypasses rules)",
        ],
        notes=(
            "Every user can read or write only their own profile document. "
            "An unauthenticated request has request.auth equals null, so "
            "isSignedIn is false and the request fails. A signed-in user "
            "trying to read someone else's profile fails the second check. "
            "Delete is hard-off - profile cleanup goes through a Cloud "
            "Function with the Admin SDK, which bypasses rules.\n\n"
            "I tested this two ways. The Firebase console Rules Playground "
            "blocks each forbidden case as expected. And in session_repository "
            "tests against a fake Firestore, the same shape of writes our "
            "rules expect is what passes - so a code-side regression that "
            "breaks the rule contract would also break the unit tests."
        ),
    ),
    # 10 - FCM lifecycle
    Slide(
        title="FCM token lifecycle",
        subtitle="Q13  -  Firebase",
        body=[
            "1.  Sign-in   -> requestPermission()",
            "2.  getToken()  -> users/{uid}.fcmTokens (array, multi-device)",
            "3.  onTokenRefresh -> arrayUnion(new) + arrayRemove(old)",
            "4.  Foreground   -> SnackBar via active ScaffoldMessenger",
            "5.  Background / terminated -> top-level vibzcheckFcmBackgroundHandler (registered before runApp)",
            "6.  Sign-out -> arrayRemove old token (re-used device stops getting prior user's pushes)",
        ],
        notes=(
            "FCM has the most state of any feature, so I gave it its own "
            "service. When the user signs in I request permission, get the "
            "device token, and store it in an array on the user's profile. "
            "Array shape lets one user accumulate tokens across multiple "
            "devices.\n\n"
            "Delivery has three modes. Foreground gets a SnackBar via the "
            "active ScaffoldMessenger. Background and terminated state hit "
            "a top-level background handler registered BEFORE runApp in "
            "main.dart - it has to be top-level so the platform can spin up "
            "a fresh isolate. Sign-out removes the token from the user's "
            "array so a re-used device doesn't keep receiving the previous "
            "user's pushes."
        ),
    ),
    # 11 - Vote sync bug
    Slide(
        title="Sync bug: voting twice didn't zero the score",
        subtitle="Q3  -  Implementation (sync)",
        body=[
            "Before (subtly wrong - real Firestore preserves null map entries):",
            {"code": "votes[uid] = null;"},
            "After (atomic, transaction-safe):",
            {
                "code": (
                    "if (effectiveVote == 0) {\n"
                    "  updates['votes.\\$uid'] = FieldValue.delete();\n"
                    "} else {\n"
                    "  updates['votes.\\$uid'] = effectiveVote;\n"
                    "}\n"
                    "tx.update(trackRef, updates);"
                )
            },
            "Pinned by the 'upvoting twice toggles the vote off' test in queue_repository_test.dart",
        ],
        notes=(
            "The most subtle bug I shipped and caught: tapping upvote twice "
            "toggled the UI off but left voteScore equals 1 in Firestore. "
            "The naive implementation cleared a vote with votes[uid] = null. "
            "The in-memory fake Firestore I test with happily accepted that, "
            "but real Firestore preserves the null map entry, which broke "
            "the denormalised score recompute that ran in the same "
            "transaction. The fix is a dotted-path delete inside the same "
            "transaction. The 'upvoting twice toggles the vote off' test "
            "now pins this contract."
        ),
    ),
    # 12 - Failure case: Spotify fallback + add-track rework
    Slide(
        title="Failure-case ownership: narrowed rethrow + mock fallback",
        subtitle="Q7 + Q2  -  Testing + Implementation (rework)",
        body=[
            {
                "code": (
                    "} on FirebaseFunctionsException catch (e, stack) {\n"
                    "  if (e.code == 'unauthenticated' ||\n"
                    "      e.code == 'failed-precondition') {\n"
                    "    rethrow;   // user / config errors fallback can't fix\n"
                    "  }\n"
                    "  return _fallback.search(query);  // mock catalogue\n"
                    "}"
                )
            },
            "Add-track screen reworked: no more auto-empty search on mount",
            "Empty state now reads: 'Type a song, artist, or album to search Spotify.'",
            "Saves a function invocation + Spotify quota every time the screen is opened",
        ],
        notes=(
            "The first version of my Spotify repository rethrew every "
            "FirebaseFunctionsException, which meant a single Cloud Function "
            "hiccup emptied the Add Track screen. I redesigned the response "
            "so the repo narrows the rethrow set: only unauthenticated and "
            "failed-precondition come through, because those are real user "
            "errors a fallback would mask. Everything else falls through to "
            "a mock catalogue so the user always sees results.\n\n"
            "I also reworked the Add Track screen itself. Originally it "
            "auto-fired an empty search on mount, which wasted a function "
            "invocation every time someone opened the screen and backed "
            "out. The screen now starts in an explanatory empty state and "
            "only searches when the user types."
        ),
    ),
    # 13 - Auth error UX
    Slide(
        title="Auth-error UX: account enumeration is a feature flag I left OFF",
        subtitle="Q8  -  Testing",
        body=[
            {
                "code": (
                    "user-not-found      -+\n"
                    "wrong-password      +-->  'Email or password is incorrect.'\n"
                    "invalid-credential  -+"
                )
            },
            "Three different Firebase codes deliberately collapsed into ONE line",
            "Stops attackers from enumerating which emails have accounts",
            "11 cases pinned in test/features/auth/auth_error_messages_test.dart",
            "Future change to the switch is forced to ship with a paired test",
        ],
        notes=(
            "When sign-in fails, attackers must not be able to figure out "
            "which half of the credential pair was wrong - that would let "
            "them enumerate which emails have accounts. So my error mapper "
            "deliberately collapses three different Firebase Auth codes - "
            "user-not-found, wrong-password, and invalid-credential - into "
            "one shared 'Email or password is incorrect.' line. Eleven tests "
            "in auth_error_messages_test.dart pin this exhaustively, so a "
            "future addition to the switch is forced to ship with a paired "
            "test."
        ),
    ),
    # 14 - Performance under real use
    Slide(
        title="Performance: profile the right side of the wire",
        subtitle="Q9  -  Testing",
        body=[
            "Symptom: home-screen sessions list spun forever for both emulators",
            {
                "code": (
                    "$ adb logcat | rg FAILED_PRECONDITION\n"
                    "FAILED_PRECONDITION: The query requires an index.\n"
                    "  You can create it here: https://console.firebase...\n\n"
                    "(after index deploy)\n"
                    "first emission resolved in 187 ms"
                )
            },
            "Fix: composite index added to firestore.indexes.json (reproducible, in source)",
            "Same playbook fixed an identical bug in the queue listener (Bug 4)",
            "Takeaway: when a request leaves the device, look at the SERVER's logs first",
        ],
        notes=(
            "The home screen sessions list spun forever for both emulators "
            "after the join-by-code rewrite. I profiled it the same way I'd "
            "profile any production issue - adb logcat in a side terminal - "
            "and the smoking gun was right there: FAILED_PRECONDITION, "
            "query requires an index. Added the composite index to "
            "firestore.indexes.json, redeployed, and first emission dropped "
            "to sub-200 milliseconds. Near-identical bug recurred for the "
            "queue listener once Phase 3 added the played == false filter; "
            "same playbook resolved it.\n\n"
            "Takeaway: when a request leaves the device, the right first "
            "move is to inspect the server's logs, not the client's."
        ),
    ),
    # 15 - AI helper + grad fairness
    Slide(
        title="AI helper + graduate-level fairness ranker",
        subtitle="Supports Q1  -  responsible AI angle",
        body=[
            "TrackRecommender (rule-based, 100% explainable):",
            "    -  Mood match against current session mood",
            "    -  Genre overlap against members' favourites",
            "    -  Variety penalty if same artist already dominates",
            "    -  Recency penalty if track was played recently",
            "FairnessRanker (graduate extension):",
            "    -  Boost from quieter members' votes so they're not drowned out",
            "    -  Penalty for tracks already played in this session",
            "    -  Every re-rank ships with the factor it won on (UX 'why?' panel)",
            "Tests: track_recommender_test.dart + fairness_ranker_test.dart",
        ],
        notes=(
            "The AI must-solve helper is a transparent rule-based "
            "recommender. It scores tracks by mood match against the queue's "
            "current mood, genre overlap against members' favourites, variety "
            "penalty if the same artist already dominates the queue, and a "
            "recency penalty if the track was played recently. Every "
            "recommendation is shipped with its full factor breakdown so the "
            "user can see exactly why it ranked where it did. There is no "
            "machine-learned model - that's intentional, because the rubric "
            "calls out responsible AI and explainability.\n\n"
            "The graduate fairness module is the second pass. It re-ranks the "
            "queue using member participation - quieter members get a small "
            "boost. Same explainability shape: every re-rank is shown with "
            "the factor it won on."
        ),
    ),
    # 16 - Tests + evidence
    Slide(
        title="Tests, bug log, and the submission bundle",
        subtitle="Supports the rubric's Functionality & Testing slice",
        body=[
            {
                "code": (
                    "$ flutter test\n"
                    "00:05 +62: All tests passed!"
                )
            },
            "Nine test files: auth errors, chat, fairness, recommender, mood, queue, session, Spotify, theme",
            "submission/ ships:",
            "    -  BUG_LOG.md             (six bugs, root-cause format)",
            "    -  CURATED_QUESTIONS.md   (14 selected questions, full answers + cited code)",
            "    -  Curated_Questions.docx (the rubric's questions-only doc)",
            "    -  screenshots/           (baseline + capture guide for slide-ready shots)",
            "    -  Vibzcheck-1.0.0-release.apk  (signed, 50.5 MB, sideload-ready)",
        ],
        notes=(
            "Sixty-two tests, all green: nine test files covering the "
            "recommender, the fairness ranker, the queue voting transaction, "
            "the session lifecycle, the Spotify repository fallback contract, "
            "the auth error mapping, the chat repo, the mood summary, and "
            "theme rendering.\n\n"
            "Everything the grader needs lives in submission. The bug log is "
            "the diary of the six hardest fixes. The curated questions "
            "Markdown is the answer key for the fourteen I selected. The "
            "release APK is signed and ready to sideload."
        ),
    ),
    # 17 - If I restarted tomorrow
    Slide(
        title="If I restarted tomorrow",
        subtitle="Supports Q14  -  Reflection",
        body=[
            "1.  Bring firebase emulator-suite into the repo from day one",
            "        -  security rule changes get unit-tested instead of caught at runtime",
            "2.  Route every mutation through Cloud Functions (Admin SDK)",
            "        -  client-side write rules collapse to 'never'",
            "        -  rule file becomes a handful of read-only allows",
            "        -  blast radius for any future schema mistake is much smaller",
        ],
        notes=(
            "If I restarted tomorrow on the same Flutter and Firebase "
            "substrate, two things would change.\n\n"
            "One, the Firebase emulator suite would be in the repo from day "
            "one. Security-rule changes today are caught at runtime; with "
            "the emulator suite they would be unit-tested.\n\n"
            "Two, every mutation would go through a Cloud Function with the "
            "Admin SDK rather than directly from the client to Firestore. "
            "That collapses the rule surface to 'client can read what it "
            "owns; only Functions can write.' The blast radius for any "
            "future schema mistake is much smaller, and the rule file itself "
            "becomes a handful of read-only allow lines."
        ),
    ),
    # 18 - Close
    Slide(
        title="Thank you",
        subtitle="Questions?",
        body=[
            "Repo:  github.com/Tmaku18/vibzcheck-project2",
            "APK:   submission/Vibzcheck-1.0.0-release.apk",
            "Q&A pack: submission/CURATED_QUESTIONS.md",
            "All five required Firebase services live, transparent AI, graduate fairness ranking",
        ],
        notes=(
            "That's Vibzcheck. Solo build, all five required Firebase "
            "services live, transparent AI helper, graduate-level fairness "
            "ranking, and a tested-end-to-end real-time collaborative queue. "
            "The repo is public, the APK is signed, and I'm happy to take "
            "questions."
        ),
    ),
]


# --- Rendering helpers ----------------------------------------------------


def set_solid(fill, color: RGBColor) -> None:
    fill.solid()
    fill.fore_color.rgb = color


def add_background(slide, color: RGBColor) -> None:
    bg = slide.shapes.add_shape(
        MSO_SHAPE.RECTANGLE, 0, 0, SLIDE_W, SLIDE_H
    )
    bg.line.fill.background()
    set_solid(bg.fill, color)
    # Push the background to the back so titles sit above it.
    spTree = bg._element.getparent()
    spTree.remove(bg._element)
    spTree.insert(2, bg._element)


def add_accent_bar(slide) -> None:
    bar = slide.shapes.add_shape(
        MSO_SHAPE.RECTANGLE, 0, 0, Inches(0.18), SLIDE_H
    )
    bar.line.fill.background()
    set_solid(bar.fill, ACCENT)


def add_title_block(slide, title: str, subtitle: str | None) -> Emu:
    """Adds the title + optional curated-question tag.

    Returns the y-offset where body content should start.
    """
    title_box = slide.shapes.add_textbox(
        Inches(0.55), Inches(0.45), Inches(12.4), Inches(0.9)
    )
    tf = title_box.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = title
    run = p.runs[0]
    run.font.name = SANS
    run.font.size = Pt(34)
    run.font.bold = True
    run.font.color.rgb = INK

    body_top = Inches(1.45)

    if subtitle:
        tag_box = slide.shapes.add_textbox(
            Inches(0.55), Inches(1.25), Inches(12.4), Inches(0.4)
        )
        tag_tf = tag_box.text_frame
        tag_tf.word_wrap = True
        sp = tag_tf.paragraphs[0]
        sp.text = subtitle
        srun = sp.runs[0]
        srun.font.name = SANS
        srun.font.size = Pt(14)
        srun.font.bold = False
        srun.font.italic = True
        srun.font.color.rgb = ACCENT
        body_top = Inches(1.85)

    # Subtle horizontal rule under the title.
    rule = slide.shapes.add_connector(
        1,  # straight line connector
        Inches(0.55),
        body_top - Inches(0.18),
        Inches(12.78),
        body_top - Inches(0.18),
    )
    rule.line.color.rgb = RULE
    rule.line.width = Pt(0.75)

    return body_top


def add_bullet_paragraph(tf, text: str, *, first: bool) -> None:
    p = tf.paragraphs[0] if first else tf.add_paragraph()
    p.text = text
    p.alignment = PP_ALIGN.LEFT
    for run in p.runs:
        run.font.name = SANS
        run.font.size = Pt(18)
        run.font.color.rgb = INK
    p.space_after = Pt(6)


def add_code_block(slide, code: str, top: Emu) -> Emu:
    """Renders a fixed-pitch code block. Returns the new content top."""
    lines = code.splitlines() or [""]
    line_height = Pt(15.5)
    height = Emu(int(line_height * (len(lines) + 1.2)))
    box = slide.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE,
        Inches(0.55),
        top,
        Inches(12.23),
        height,
    )
    box.line.color.rgb = RULE
    box.line.width = Pt(0.5)
    set_solid(box.fill, CODE_BG)
    box.adjustments[0] = 0.04

    tf = box.text_frame
    tf.word_wrap = False
    tf.margin_left = Inches(0.18)
    tf.margin_right = Inches(0.18)
    tf.margin_top = Inches(0.08)
    tf.margin_bottom = Inches(0.08)
    for i, line in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.text = line if line else " "
        p.alignment = PP_ALIGN.LEFT
        for run in p.runs:
            run.font.name = MONO
            run.font.size = Pt(13)
            run.font.color.rgb = INK
        p.space_after = Pt(0)

    return top + height + Inches(0.15)


def add_table_block(slide, rows: list[tuple[str, str]], top: Emu) -> Emu:
    n = len(rows)
    height = Inches(0.46) * n
    table_shape = slide.shapes.add_table(
        n, 2, Inches(0.55), top, Inches(12.23), height
    )
    table = table_shape.table
    table.columns[0].width = Inches(2.4)
    table.columns[1].width = Inches(9.83)
    for r, (left, right) in enumerate(rows):
        for c, value in enumerate((left, right)):
            cell = table.cell(r, c)
            cell.fill.solid()
            cell.fill.fore_color.rgb = TAG_BG if c == 0 else BG_COLOR
            tf = cell.text_frame
            tf.margin_left = Inches(0.12)
            tf.margin_right = Inches(0.12)
            tf.margin_top = Inches(0.04)
            tf.margin_bottom = Inches(0.04)
            p = tf.paragraphs[0]
            p.text = value
            for run in p.runs:
                run.font.name = SANS
                run.font.size = Pt(15)
                run.font.bold = c == 0
                run.font.color.rgb = ACCENT if c == 0 else INK
    return top + height + Inches(0.2)


def add_body(slide, body: list[object], top: Emu) -> None:
    """Renders the slide body. Bullets land in one shared text frame so
    they keep tight vertical rhythm; code/table blocks open new shapes
    after closing the previous bullet group."""
    bullet_buffer: list[str] = []

    def flush_bullets(start: Emu) -> Emu:
        nonlocal bullet_buffer
        if not bullet_buffer:
            return start
        line_height = Pt(26)
        height = Emu(int(line_height * (len(bullet_buffer) + 0.5)))
        box = slide.shapes.add_textbox(
            Inches(0.55), start, Inches(12.23), height
        )
        tf = box.text_frame
        tf.word_wrap = True
        for i, line in enumerate(bullet_buffer):
            add_bullet_paragraph(tf, line, first=i == 0)
        bullet_buffer = []
        return start + height + Inches(0.05)

    cursor = top
    for block in body:
        if isinstance(block, str):
            bullet_buffer.append(block)
        else:
            cursor = flush_bullets(cursor)
            if "code" in block:
                cursor = add_code_block(slide, block["code"], cursor)
            elif "table" in block:
                cursor = add_table_block(slide, block["table"], cursor)
    flush_bullets(cursor)


def render_title_slide(slide, spec: Slide) -> None:
    title_box = slide.shapes.add_textbox(
        Inches(1.0), Inches(2.4), Inches(11.3), Inches(1.6)
    )
    tf = title_box.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = spec.title
    p.alignment = PP_ALIGN.LEFT
    run = p.runs[0]
    run.font.name = SANS
    run.font.size = Pt(72)
    run.font.bold = True
    run.font.color.rgb = INK

    sub_box = slide.shapes.add_textbox(
        Inches(1.0), Inches(4.1), Inches(11.3), Inches(2.0)
    )
    sf = sub_box.text_frame
    sf.word_wrap = True
    if spec.subtitle:
        for i, line in enumerate(spec.subtitle.split("\n")):
            p = sf.paragraphs[0] if i == 0 else sf.add_paragraph()
            p.text = line
            for run in p.runs:
                run.font.name = SANS
                run.font.size = Pt(22) if i == 0 else Pt(16)
                run.font.color.rgb = INK_MUTED if i > 0 else ACCENT
            p.space_after = Pt(8)


def render_content_slide(slide, spec: Slide) -> None:
    body_top = add_title_block(slide, spec.title, spec.subtitle)
    add_body(slide, spec.body, body_top)


def attach_notes(slide, notes_text: str) -> None:
    notes_slide = slide.notes_slide
    tf = notes_slide.notes_text_frame
    tf.text = notes_text


# --- Build ----------------------------------------------------------------


def build() -> Presentation:
    prs = Presentation()
    prs.slide_width = SLIDE_W
    prs.slide_height = SLIDE_H

    blank_layout = prs.slide_layouts[6]  # blank

    for spec in SLIDES:
        slide = prs.slides.add_slide(blank_layout)
        add_background(slide, BG_COLOR)
        add_accent_bar(slide)
        if spec.layout == "title":
            render_title_slide(slide, spec)
        else:
            render_content_slide(slide, spec)
        if spec.notes:
            attach_notes(slide, spec.notes)

    return prs


def main() -> None:
    prs = build()
    prs.save(OUT_PATH)
    print(f"Wrote {OUT_PATH}  ({len(SLIDES)} slides)")


if __name__ == "__main__":
    main()
