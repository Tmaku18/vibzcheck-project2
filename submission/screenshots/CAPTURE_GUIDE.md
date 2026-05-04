# Screenshot Capture Guide

Vibzcheck's submission slides + bug log reference screenshots in this folder.
Two were captured automatically at the end of Phase 4 (`01_device-a_current.png`,
`02_device-b_current.png`). Use the commands below to refresh those or add
new shots before final submission.

## Live emulator capture

```powershell
# Pixel "Device A" (owner)
adb -s emulator-5554 exec-out screencap -p > submission\screenshots\01_device-a_current.png

# Pixel "Device B" (joiner)
adb -s emulator-5556 exec-out screencap -p > submission\screenshots\02_device-b_current.png
```

## Recommended demo coverage

Before recording the demo, walk through these screens and capture each one
on whichever device is showing it. They map 1-for-1 to the rubric:

| Screen                           | Why it matters                                     | Suggested filename                  |
| -------------------------------- | -------------------------------------------------- | ----------------------------------- |
| Sign-in screen                   | Firebase Auth surface                              | `10_signin.png`                     |
| Sign-up + profile creation       | First-run user bootstrap + Firestore profile write | `11_signup.png`                     |
| Home screen with sessions list   | `array-contains` + composite index in action       | `20_home_sessions.png`              |
| Create-session sheet             | Session lifecycle entrypoint                       | `21_create_session.png`             |
| Join-by-code sheet               | Public `joinCodes` mapping in use                  | `22_join_by_code.png`               |
| Inside a session                 | Real-time queue + voting UI                        | `30_session_overview.png`           |
| Add-track screen with Spotify    | `searchTracks` Cloud Function bridge               | `31_add_track_spotify_results.png`  |
| Mood chip filter                 | Mood-tagging feature                               | `32_add_track_mood_filter.png`      |
| Vote toggling on a track         | Transaction-safe voting                            | `40_voting_in_progress.png`         |
| Suggestions card (rule-based)    | AI must-solve helper                               | `50_suggestions_basic.png`          |
| Suggestions card (fair-ranking)  | Graduate-level fairness explainability             | `51_suggestions_fair_ranking.png`   |
| Per-factor "why?" expansion      | Transparent recommendations evidence               | `52_suggestions_explain.png`        |
| Chat tab with messages           | Storage + chat feature                             | `60_chat.png`                       |
| FCM foreground snackbar          | Notification permission + delivery                 | `70_fcm_foreground.png`             |
| Profile screen with avatar       | Firebase Storage avatar upload                     | `80_profile_avatar.png`             |
| End-session confirmation         | Owner-only lifecycle action                        | `90_end_session.png`                |

## Capture tips

- The `exec-out screencap -p` form streams a raw PNG directly to disk
  without the historical `\r\n` mangling problem of `adb pull /sdcard/...`.
- If both emulators are showing the same screen, capture one and rename it
  rather than capturing twice — keeps the bundle small.
- Crop or annotate later if needed; commit the originals untouched here.
