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
    # Phone screenshot(s) to dock on the right of the slide. May be a single
    # path (relative to this file's parent) or a list for side-by-side
    # multi-phone shots. When set, the body content area auto-shrinks so
    # it doesn't collide with the image(s).
    image: str | list[str] | None = None


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
        title="Live demo: two phones, one shared playlist",
        subtitle="Demo (Slide 2)",
        body=[
            "Alice creates a session called 'Friday Vibes'",
            "Bob joins using the six-character code Alice reads aloud",
            "Both see the same live queue instantly",
            "Alice adds 'Blinding Lights' from Spotify",
            "Bob upvotes — the count updates on both screens in real time",
            "The AI suggests the next song and explains why",
        ],
        image=[
            "screenshots/20_home_sessions.png",
            "screenshots/30_session_with_queue.png",
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
        title="What I built it with",
        subtitle="Simple tools that just work together",
        body=[
            "Mobile app — Flutter (one codebase that works on Android phones)",
            "Keeps everything in sync — Riverpod (modern state management)",
            "Moving between screens — go_router (remembers if you're logged in)",
            "Login and user accounts — Firebase Authentication (email + password)",
            "Live shared playlist and chat — Cloud Firestore (updates appear instantly)",
            "Profile pictures — Firebase Storage",
            "Push notifications when friends vote or join — Firebase Cloud Messaging",
            "Searching Spotify without exposing secrets — Cloud Functions (the secret stays on the server)",
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
        title="I built the hard parts in this order",
        subtitle="Q1 — Implementation",
        body=[
            "First: the shared playlist and voting system",
            "   - This tested login, the database, and security rules all at once",
            "Second: the Spotify search (through a Cloud Function on the server)",
            "   - The playlist was already working, so I could test real songs safely",
            "Third: the AI song suggestions and fairness ranking",
            "   - These use the playlist data that was already solid",
            "",
            "Building this way meant each new feature had something that already worked underneath it.",
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
        title="I kept each screen simple and easy to follow",
        subtitle="Q4 + Q5 — Architecture",
        body=[
            "The main session screen used to try to do everything at once (playlist, chat, suggestions)",
            "I split it into smaller pieces that each have one job:",
            "   • QueueTrackTile — shows one song and its vote buttons",
            "   • SuggestionsCard — shows the AI's next-song ideas with explanations",
            "   • ChatScreen — its own page so you can switch away and come back",
            "",
            "Navigation remembers whether you're logged in and sends you to the right place automatically.",
            "Adding a new screen later is just one line of code.",
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
        title="How the data is organized",
        subtitle="Q10 — Firebase",
        body=[
            "Three main collections:",
            "   • users — profile and preferences",
            "   • sessions — the playlist room itself",
            "   • joinCodes — lookup so friends can join with a 6-letter code",
            "",
            "Inside each session: members, queue (songs), messages (chat), suggestions (AI)",
            "",
            "This makes security rules simple and screens fast — leaving cleans up automatically.",
        ],
        image="screenshots/20_home_sessions.png",
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
        title="The join-by-code problem (and how I fixed it)",
        subtitle="Q14 + Q6 — Reflection + Architecture",
        body=[
            "Early version: to join you had to see every session — that broke privacy rules",
            "Solution:",
            "   1. A small public lookup table (joinCodes) anyone logged in can read",
            "   2. A rule that lets a new person add ONLY themselves to the member list",
            "",
            "This pattern is now my go-to for any 'share this link' feature.",
            "Hardest bug I fixed — see Bug 2 in the bug log.",
        ],
        image="screenshots/30_session_with_queue.png",
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
        title="Making the home screen fast again",
        subtitle="Q11 — Firebase",
        body=[
            "The home screen asks: 'show me all the sessions I'm part of, newest first'",
            "That combination of filters needs a special index in the database",
            "I added it to a file called firestore.indexes.json so it gets deployed automatically",
            "",
            "Without it the screen would spin forever. With it the list appears in under 200 milliseconds.",
            "Same fix was needed for the playlist view once we started hiding played songs.",
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
        title="Only you can edit your own profile",
        subtitle="Q12 — Firebase",
        body=[
            "Rule: if the person asking is logged in as you, they can read and change your profile",
            "If they're not logged in, or they're looking at someone else's profile, the request is blocked",
            "Deleting profiles is turned off completely — handled through a secure server process",
            "",
            "I tested this in the Firebase console and with automated tests so I know it works.",
        ],
        image="screenshots/11_signup.png",
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
        title="How push notifications work",
        subtitle="Q13 — Firebase",
        body=[
            "When you sign in the app asks for permission to send notifications",
            "It saves a unique token for your phone in your user profile",
            "If you get a new phone or the token changes, it updates automatically",
            "Notifications show up as a little message at the bottom of the screen when you're using the app",
            "Even if the app is closed, the phone can still wake up and show the message",
            "When you sign out, your token is removed so you stop getting the previous person's notifications",
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
        title="Voting twice didn't zero the score (fixed with a transaction)",
        subtitle="Q3 — Implementation (sync)",
        body=[
            "Early bug: tapping upvote twice looked correct but the score stayed at 1 in the database",
            "Cause: clearing a vote with votes[uid] = null didn't remove the key in real Firestore",
            "Fix: use FieldValue.delete() inside a transaction — vote, score, and counters update atomically",
            {
                "code": (
                    "if (effectiveVote == 0) {\n"
                    "  updates['votes.$uid'] = FieldValue.delete();\n"
                    "} else {\n"
                    "  updates['votes.$uid'] = effectiveVote;\n"
                    "}\n"
                    "tx.update(trackRef, updates);"
                )
            },
            "Locked in by a unit test so it can't regress.",
        ],
        image="screenshots/30_session_with_queue.png",
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
        title="When the Spotify search fails, the app still works",
        subtitle="Q7 + Q2 — Testing + Implementation (rework)",
        body=[
            "The app calls a Cloud Function to search Spotify (secret stays safe on the server)",
            "If the function fails, the app falls back to a built-in list instead of showing nothing",
            "Add Track no longer auto-searches when you open it — you type first",
            "Saves server calls and feels faster",
        ],
        image="screenshots/31_add_track_drake.png",
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
        title="Sign-in errors are friendly and safe",
        subtitle="Q8 — Testing",
        body=[
            "Instead of technical messages like 'user-not-found' or 'wrong-password', the app shows one line:",
            "'Email or password is incorrect.'",
            "",
            "Deliberate — it stops anyone from figuring out which emails have accounts (security best practice).",
            "11 automated tests guarantee the friendly message can never leak technical details.",
        ],
        image="screenshots/10_signin.png",
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
        title="Performance: the home screen used to spin forever",
        subtitle="Q9 — Testing",
        body=[
            "After adding the join-by-code feature, the home screen would show a loading spinner and never finish",
            "The phone logs told me exactly why: 'The query requires an index'",
            "I added the missing index to a file called firestore.indexes.json and redeployed",
            "The list now loads in under 200 milliseconds on both phones",
            "The same fix was needed later for the playlist view once we started hiding already-played songs",
            "",
            "Lesson: when something is slow, look at the server logs first, not just the phone screen.",
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
        title="The AI song suggester + fairness ranking",
        subtitle="Graduate extension (supports Q1)",
        body=[
            "Suggests the next three songs using simple rules — no black-box AI:",
            "   • Does it match the room's current mood?",
            "   • Does it fit what people usually like?",
            "   • Has the same artist played too much?",
            "   • Was it played recently?",
            "",
            "A 'fairness' step boosts songs from quieter members so they aren't drowned out.",
            "Every pick shows its reasoning (see right) so the group can trust it.",
            "Both fully tested so they can't break silently.",
        ],
        image="screenshots/50_suggestions_with_why.png",
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
        title="Everything you need to check my work",
        subtitle="Supports the rubric's Functionality & Testing slice",
        body=[
            "62 automated tests all pass — including tests for voting, the AI suggestions, the fairness ranking, and the Spotify fallback",
            "A bug log explains the six hardest problems I ran into and exactly how I fixed them",
            "The full answer key with code references is in CURATED_QUESTIONS.md",
            "A separate Word document with only the questions (as the rubric asks) is also included",
            "Screenshots from both phones and a signed release APK are in the submission folder",
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
        title="If I started this project again from scratch",
        subtitle="Q14 — Reflection",
        body=[
            "I would do two things differently from day one:",
            "",
            "1. Use the Firebase emulator tools right from the beginning so I could test security rules automatically instead of finding bugs only when two phones tried to join the same session",
            "",
            "2. Have every change to the database go through a Cloud Function instead of letting the phone write directly. That would make the security rules much simpler and reduce the chance of mistakes.",
            "",
            "These changes would have saved me the two biggest bugs I hit during the project.",
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
        title="Thank you — any questions?",
        subtitle="",
        body=[
            "GitHub repo: github.com/Tmaku18/vibzcheck-project2",
            "Signed APK is in the submission folder",
            "Full answer key, bug log, and screenshots are all there too",
            "",
            "I built a complete, real-time collaborative music app that meets every requirement in the project brief, including the graduate-level fairness ranking and transparent AI suggestions.",
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


def add_code_block(slide, code: str, top: Emu, right: Emu = Inches(12.78)) -> Emu:
    """Renders a fixed-pitch code block. Returns the new content top.

    `right` is the x coordinate the block must not cross — used to leave
    room for a docked phone screenshot on the right side of the slide.
    """
    lines = code.splitlines() or [""]
    line_height = Pt(15.5)
    height = Emu(int(line_height * (len(lines) + 1.2)))
    width = right - Inches(0.55)
    box = slide.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE,
        Inches(0.55),
        top,
        width,
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


def add_table_block(
    slide, rows: list[tuple[str, str]], top: Emu, right: Emu = Inches(12.78)
) -> Emu:
    n = len(rows)
    height = Inches(0.46) * n
    width = right - Inches(0.55)
    table_shape = slide.shapes.add_table(n, 2, Inches(0.55), top, width, height)
    table = table_shape.table
    # Keep the label column proportional to the table width.
    label_w = Inches(2.4)
    table.columns[0].width = label_w
    table.columns[1].width = width - label_w
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


def add_body(
    slide, body: list[object], top: Emu, right: Emu = Inches(12.78)
) -> None:
    """Renders the slide body. Bullets land in one shared text frame so
    they keep tight vertical rhythm; code/table blocks open new shapes
    after closing the previous bullet group.

    `right` is the x coordinate the body must not cross — narrower when
    a phone screenshot is docked on the right side of the slide.
    """
    bullet_buffer: list[str] = []
    width = right - Inches(0.55)

    def flush_bullets(start: Emu) -> Emu:
        nonlocal bullet_buffer
        if not bullet_buffer:
            return start
        line_height = Pt(26)
        height = Emu(int(line_height * (len(bullet_buffer) + 0.5)))
        box = slide.shapes.add_textbox(Inches(0.55), start, width, height)
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
                cursor = add_code_block(slide, block["code"], cursor, right=right)
            elif "table" in block:
                cursor = add_table_block(slide, block["table"], cursor, right=right)
    flush_bullets(cursor)


# Native size of the captured Android phone screenshots (385 x 814).
PHONE_ASPECT = 814 / 385  # ~2.114


def add_phone_image(slide, image_path: str, x: Emu, top: Emu, height: Emu):
    """Drops a phone-aspect screenshot and returns its bounding box."""
    width = Emu(int(height / PHONE_ASPECT))
    pic = slide.shapes.add_picture(image_path, x, top, width=width, height=height)
    return pic


def render_images(slide, image_field, body_top: Emu) -> Emu:
    """Docks one or two phone screenshots on the right side of the slide.

    Returns the x coordinate the body content must stay left of (so text
    and images never collide).
    """
    if image_field is None:
        return Inches(12.78)

    paths = image_field if isinstance(image_field, list) else [image_field]
    base = Path(__file__).resolve().parent
    full_paths = [str((base / p).resolve()) for p in paths]

    # Available vertical room: from body_top to slide bottom minus margin.
    avail_height = SLIDE_H - body_top - Inches(0.4)

    if len(full_paths) == 1:
        # Bigger single phone: cap at 5.0" tall.
        h = min(avail_height, Inches(5.0))
        w = Emu(int(h / PHONE_ASPECT))
        gutter = Inches(0.2)
        right_edge = Inches(12.78)
        x = right_edge - w
        add_phone_image(slide, full_paths[0], x, body_top, h)
        return x - gutter

    # Two phones side by side, slightly smaller so both fit.
    h = min(avail_height, Inches(4.6))
    w = Emu(int(h / PHONE_ASPECT))
    inner_gap = Inches(0.2)
    gutter = Inches(0.2)
    right_edge = Inches(12.78)
    x2 = right_edge - w
    x1 = x2 - inner_gap - w
    add_phone_image(slide, full_paths[1], x2, body_top, h)
    add_phone_image(slide, full_paths[0], x1, body_top, h)
    return x1 - gutter


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
    body_right = render_images(slide, spec.image, body_top)
    add_body(slide, spec.body, body_top, right=body_right)


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
