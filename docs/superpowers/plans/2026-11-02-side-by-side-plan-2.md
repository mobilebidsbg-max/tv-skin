# Plan 2: Side by side (two windows)

> **Status 2026-11-02: built and tested on the TV, then removed at Dimitar's request ("too complicated"). Last commit with the code: e52db91; removal: a0c988e.**

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** two apps on screen at once, in the Apple-like layout of mockup v3 (50/50 or 70/30). The side you control has the sound; the other side keeps playing silently. A glass control bar is opened with Home.

**Spec:** `docs/superpowers/specs/2026-11-01-tv-home-screen-design.md`, section "Side by side". Spike A was done on the TV on 2026-11-02 and settles the routes.

## Spike A results (TCL, Android 14, 2026-11-02)

| Question | Answer on the TV |
|---|---|
| Freeform windows | They work after `settings put global enable_freeform_support 1` and `force_resizable_activities 1`, plus a reboot (already done). The system declares no freeform feature, but `am start --windowingMode 5` works. |
| Position and size | `am task resize <taskId> l t r b` in 1920×1080 coordinates. A full-screen window is resize `0 0 1920 1080`. |
| Task ids | `cmd activity stack list` prints `taskId=N: <pkg>/<activity> bounds=…` |
| Silent side | `appops set <pkg> PLAY_AUDIO ignore` mutes the app and playback continues (`mutedState:appOps`). `default` restores it. |
| Moving control | Starting the app's own launch intent again brings its task to the front with focus, and the other window keeps playing. A tap at the window's edge works too. |
| Home | Home hides both windows and YouTube pauses, so Home ends side by side unless it is intercepted. |
| Limits | Three apps at once makes YouTube ANR and close (low RAM), so two is the maximum. Netflix shows its UI in a window; DRM video in a window is untested. Netflix blocks screenshots. |

## Decisions (my calls)

- The launcher gets shell rights with dadb 2.0.0 (adb client) on `127.0.0.1:5555`, using its own RSA key in `filesDir`. The first connection shows "Allow USB debugging?" on the TV once; Dimitar picks **Always allow**.
- **Opening the controls:**
  - An AccessibilityService (`split.SplitKeys`, switched on over adb) watches keys only while side by side is on.
  - **Home** opens the bar instead of leaving.
  - While the bar is open, the service handles ◀ ▶ OK Back itself and consumes them, so the apps receive nothing.
  - If Home doesn't reach the service on this TV, use long-press Back instead (checked during Task 4).
- **Bar items:**
  - `[app A] [app B]` (control and sound) · Swap · 50/50 · 70/30 · Full screen · End.
  - End keeps the controlled app full screen and closes the other one.
  - Back closes the bar.
- **Pane positions** (v3, px in 1920×1080):
  - 50/50: `48,196–948,702` and `972,196–1872,702`.
  - 70/30: `48,118–1288,816` and `1312,118–1872,433`.
- The stage behind the windows is the launcher itself:
  - blurred, darkened wallpaper;
  - each app's name and sound icon above its window;
  - a thin white frame around the side you control;
  - the time;
  - the bar at the bottom, or a small "⌂ Controls" hint when it's closed.
- A task that disappears while side by side is on (the user exited the app): the other window goes full screen and side by side ends. The controller polls `stack list` every 3 s.

## Tasks

1. **Shell:**
   - `shell/Shell.kt`: `interface Shell { suspend fun run(cmd: String): String }`, plus `AdbShell(context)` (dadb, mutex, one reconnect).
   - Key files `adbkey`/`adbkey.pub` with the comment "TV Skin".
   - `FakeShell` for tests.
2. **Pure split logic** (`split/SplitLayout.kt`, `split/SplitCommands.kt`, `split/SplitState.kt`):
   - pane bounds;
   - command strings;
   - `taskIdFor(pkg, stackList)` parsed from the real fixture `stack-list-split.txt`;
   - the state reducer (swap, ratio, side, full, bar index).
   - Unit tests for each.
3. **SplitController:**
   - `start(a, b)`, `control(side)`, `swap()`, `ratio(r)`, `full()`, `end()`, plus polling.
   - Tests check the exact command sequence on `FakeShell`.
4. **SplitKeys** accessibility service, plus the pure `SplitKeyRouter` (key → action, consumed?), with tests. Check on the TV which keys reach the service.
5. **UI:**
   - `SplitStage` composable (snapshot);
   - the app picker from the Side by side button and from the hold menu (compose test);
   - MainActivity wiring (Home while split → `end()` if the service isn't on).
6. **TV:**
   - install;
   - switch the service on;
   - first shell connection (Dimitar approves);
   - live test with YouTube + TikTok web and YouTube + Netflix;
   - `docs/TV-INSTALL.md` rows with their undo commands.
